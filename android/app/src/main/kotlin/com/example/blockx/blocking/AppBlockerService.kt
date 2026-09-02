package com.example.blockx.blocking

import com.example.blockx.blockscreen.BlockActivity
import com.example.blockx.blockscreen.FloatingWidget
import com.example.blockx.common.BlockCatalog

import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

private const val TAG = "BlockX"

/**
 * The blocker. Detects the real foreground app (via UsageStats) and, based on
 * its per-app config, either lets it be, blocks it with [BlockActivity], shows
 * the "is this really needed?" interstitial, or (during an active timed session)
 * allows it while showing a small floating widget. See [BlockRepository].
 *
 * No VPN. Blocking pushes the app to the background so it actually pauses.
 */
class AppBlockerService : AccessibilityService() {

    companion object {
        /** The running service instance, so an activity can ask it to act. */
        @Volatile
        var instance: AppBlockerService? = null
            private set
    }

    @Volatile
    private var currentForegroundPackage: String? = null

    private var lastBlockStart = 0L
    private var lastBlockedPackage: String? = null
    private var pendingBlockLaunch: Runnable? = null
    private var lastDecisionKey: String? = null
    private var usageStatsManager: UsageStatsManager? = null

    // Website-blocking state (throttle for browser URL reads).
    private var lastUrlCheckAt = 0L
    // Ignore URL/feature checks until this time (while we send a global BACK).
    private var graceUntil = 0L

    // In-app feature blocking (Shorts / Reels) throttles.
    private var lastFeatureCheckAt = 0L
    private var lastCandidateLogAt = 0L

    private val handler = Handler(Looper.getMainLooper())
    private val recheckIntervalMs = 350L

    private val recheckRunnable = object : Runnable {
        override fun run() {
            pollForegroundApp()
            evaluate()
            // Poll-drive feature checks too, so a Shorts/Reels timed session that
            // runs out is re-evaluated even when the app stops firing content
            // events (e.g. a paused Short).
            currentForegroundPackage?.let { if (isFeatureApp(it)) checkBlockedFeature(it) }
            handler.postDelayed(this, recheckIntervalMs)
        }
    }

    private val screenUnlockReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            pollForegroundApp()
            evaluate()
        }
    }

    // Windows that are NOT the user switching apps (game side-panels, etc.).
    // Reference data lives in BlockCatalog.kt (data only, no behaviour).
    private val ignoredPackages = BlockCatalog.ignoredPackages

    private fun isIgnoredPackage(pkg: String): Boolean {
        if (ignoredPackages.contains(pkg)) return true
        return pkg.contains("gamespace", ignoreCase = true) ||
            pkg.contains("gameassistant", ignoreCase = true)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_USER_PRESENT)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenUnlockReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(screenUnlockReceiver, filter)
        }

        handler.post(recheckRunnable)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val type = event.eventType
        if (type != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            type != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            return
        }

        val pkg = event.packageName?.toString()
        if (pkg.isNullOrEmpty()) return

        // Ignore assistant/side-panel windows, and our own windows (our floating
        // widget must not be mistaken for a foreground app switch). UsageStats
        // reports our real activities when they matter.
        if (isIgnoredPackage(pkg) || pkg == packageName) return

        if (type == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            currentForegroundPackage = pkg
            evaluate()
        }

        // Website blocking: while a browser is up, watch its address bar and
        // bounce off any blocked site. We check on content-changed too, since
        // navigating within a page fires content-changed, not state-changed.
        if (isBrowser(pkg)) {
            checkBrowserUrl(pkg)
        }

        // In-app sub-feature blocking (Shorts / Reels): scan the target app's
        // view tree for the player and show the block screen when it's open.
        if (isFeatureApp(pkg)) {
            checkBlockedFeature(pkg)
        }

        // Links opened inside an app's own in-app browser (e.g. tapping a link
        // in Messenger/Instagram) — block those too.
        if (isInAppBrowserHost(pkg)) {
            checkInAppBrowserUrl(pkg)
        }
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        handler.removeCallbacks(recheckRunnable)
        pendingBlockLaunch?.let { handler.removeCallbacks(it) }
        try {
            unregisterReceiver(screenUnlockReceiver)
        } catch (_: Exception) {
        }
        floating.hide()
        return super.onUnbind(intent)
    }

    /** Reliable foreground detection: the last resumed app per UsageStats. */
    private fun pollForegroundApp() {
        val usm = usageStatsManager ?: return
        val end = System.currentTimeMillis()
        val begin = end - 60_000L
        val events = try {
            usm.queryEvents(begin, end)
        } catch (_: Exception) {
            return
        }

        var latestPkg: String? = null
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val isForeground =
                e.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                        e.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            if (isForeground) {
                latestPkg = e.packageName
            }
        }

        // Accept our own package here (so BlockActivity is recognised) but skip
        // assistant/side-panel packages so they don't unblock a hosted game.
        if (latestPkg != null && !isIgnoredPackage(latestPkg)) {
            currentForegroundPackage = latestPkg
        }
    }

    private fun evaluate() {
        val pkg = currentForegroundPackage ?: return
        // Our own screens are never blocked; keep the widget hidden over them.
        if (pkg == packageName) {
            floating.hide()
            return
        }

        val decision = BlockRepository.decide(this, pkg)
        val decisionKey = "$pkg:$decision"
        if (decisionKey != lastDecisionKey) {
            Log.d(TAG, "evaluate: $pkg -> $decision")
            lastDecisionKey = decisionKey
        }
        when (decision) {
            BlockRepository.Decision.NONE -> {
                // App isn't blocked. Keep the floating widget only if a Shorts/
                // Reels session owns it right now (checkBlockedFeature manages
                // that); otherwise hide it. This lets app-blocking still run for
                // an app that ALSO has a feature rule (e.g. blocking Instagram
                // the app on top of Instagram Reels).
                val fkey = featureApps[pkg]
                if (fkey == null || BlockRepository.sessionMillisLeft(this, fkey) <= 0) {
                    floating.hide()
                }
            }

            BlockRepository.Decision.ALLOW_SESSION -> floating.show(pkg)

            BlockRepository.Decision.INTERSTITIAL -> {
                floating.hide()
                showBlockScreen(pkg, BlockActivity.MODE_INTERSTITIAL, null)
            }

            BlockRepository.Decision.BLOCK -> {
                floating.hide()
                val reason = if (BlockRepository.configFor(this, pkg)?.mode == "timed") {
                    "Daily limit reached.\nThis app is blocked until tomorrow."
                } else {
                    null
                }
                showBlockScreen(pkg, BlockActivity.MODE_BLOCK, reason)
            }
        }
    }

    private fun showBlockScreen(pkg: String, mode: String, reason: String?) {
        if (BlockActivity.isVisible) return
        val now = SystemClock.uptimeMillis()
        if (now - lastBlockStart < 400) return

        // Some apps (e.g. Facebook) aggressively re-launch themselves to the
        // foreground, winning the race against our block screen. The same brief
        // "app is in front again" happens right after the user dismisses the
        // block screen with our "Go to home" button and reopens the app within a
        // few seconds. In both cases we send it to the background with HOME first
        // (an app can't beat the global Home action) — but then we launch the
        // block screen a beat LATER, so it reliably lands on top of the launcher.
        // Launching immediately after HOME raced the Home transition (and a still-
        // finishing singleTask block screen), which left the app closed with no
        // block screen showing at all.
        val needsHomeKick = pkg == lastBlockedPackage && now - lastBlockStart < 4000
        lastBlockStart = now
        lastBlockedPackage = pkg

        Log.d(TAG, "showBlockScreen: $pkg mode=$mode homeKick=$needsHomeKick")

        pendingBlockLaunch?.let { handler.removeCallbacks(it) }
        pendingBlockLaunch = null

        if (needsHomeKick) {
            performGlobalAction(GLOBAL_ACTION_HOME)
            val launch = Runnable { launchBlockActivity(pkg, mode, reason) }
            pendingBlockLaunch = launch
            handler.postDelayed(launch, 350L)
        } else {
            launchBlockActivity(pkg, mode, reason)
        }
    }

    private fun launchBlockActivity(
        pkg: String,
        mode: String,
        reason: String?,
        feature: Boolean = false,
    ) {
        pendingBlockLaunch = null
        if (BlockActivity.isVisible) return

        val intent = Intent(this, BlockActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION,
            )
            putExtra(BlockActivity.EXTRA_PACKAGE, pkg)
            putExtra(BlockActivity.EXTRA_MODE, mode)
            putExtra(BlockActivity.EXTRA_REASON, reason)
            putExtra(BlockActivity.EXTRA_FEATURE, feature)
        }
        try {
            startActivity(intent)
            Log.d(TAG, "launched BlockActivity for $pkg")
        } catch (e: Exception) {
            Log.w(TAG, "failed to launch BlockActivity for $pkg", e)
        }
    }

    // ---- Website blocking (browser URL detection) ----

    // Browser packages + address-bar id suffixes live in BlockCatalog.kt.
    private val browserPackages = BlockCatalog.browserPackages
    private val urlBarIdSuffixes = BlockCatalog.urlBarIdSuffixes

    private fun isBrowser(pkg: String): Boolean = browserPackages.contains(pkg)

    /** Read the current browser URL; if it's a blocked site, show the block screen. */
    private fun checkBrowserUrl(pkg: String) {
        if (BlockActivity.isVisible) return
        val now = SystemClock.uptimeMillis()
        if (now < graceUntil) return
        if (now - lastUrlCheckAt < 300) return
        lastUrlCheckAt = now

        val url = readBrowserUrl(pkg) ?: return
        if (!BlockRepository.isBlockedHost(this, url)) return

        // Full-screen block screen (MODE_BACK: its close button sends the browser
        // back to its own home, not the phone home). Only fires for a loaded
        // page, not while typing — see readBrowserUrl.
        Log.d(TAG, "blocked site in $pkg: \"$url\" -> block screen")
        showBlockScreen(pkg, BlockActivity.MODE_BACK, "This website is blocked.")
    }

    /**
     * Called by the "Go back" block screen (website or in-app feature): send a
     * global BACK shortly after the block screen finishes — returning to the
     * previous page/screen (browser home, or the feed/chat you came from) — and
     * pause URL/feature checks meanwhile so the still-showing blocked content
     * doesn't instantly re-trigger a block.
     */
    fun goBackAndPause() {
        graceUntil = SystemClock.uptimeMillis() + 2000
        handler.postDelayed({ performGlobalAction(GLOBAL_ACTION_BACK) }, 200L)
    }

    private fun readBrowserUrl(pkg: String): String? {
        val root = try {
            rootInActiveWindow
        } catch (_: Exception) {
            null
        } ?: return null

        for (suffix in urlBarIdSuffixes) {
            val nodes = try {
                root.findAccessibilityNodeInfosByViewId("$pkg:id/$suffix")
            } catch (_: Exception) {
                null
            }
            if (nodes.isNullOrEmpty()) continue
            for (node in nodes) {
                // Skip while the address bar is focused — the user is typing or an
                // autocomplete suggestion is showing (e.g. history completing
                // "tgc.com" to "tgc.edu.bd"). Only act once a page is actually
                // loaded (bar not focused), so navigation isn't blocked mid-type.
                if (node.isFocused) continue
                val text = node.text?.toString()
                if (!text.isNullOrBlank()) return text
            }
        }
        return null
    }

    // ---- In-app browsers (links opened inside Messenger/Instagram/etc.) ----

    // Apps that open tapped links in their OWN in-app browser (a WebView inside
    // the app), so the foreground package stays the app, not Chrome. Links that
    // open a Chrome Custom Tab instead run under com.android.chrome and are
    // already caught by the normal browser path above.
    private val inAppBrowserHosts = BlockCatalog.inAppBrowserHosts

    private var lastInAppCheckAt = 0L
    private var lastInAppLogAt = 0L

    private fun isInAppBrowserHost(pkg: String): Boolean = inAppBrowserHosts.contains(pkg)

    private fun checkInAppBrowserUrl(pkg: String) {
        if (BlockActivity.isVisible) return
        val now = SystemClock.uptimeMillis()
        if (now < graceUntil) return
        if (now - lastInAppCheckAt < 400) return
        lastInAppCheckAt = now

        val root = try {
            rootInActiveWindow
        } catch (_: Exception) {
            null
        } ?: return

        val url = findBlockedInAppUrl(root, now) ?: return
        Log.d(TAG, "blocked in-app site in $pkg: \"$url\" -> block screen")
        showBlockScreen(pkg, BlockActivity.MODE_BACK, "This website is blocked.")
    }

    /**
     * Looks for a blocked URL shown at the top of an in-app browser. Requires an
     * actual WebView on screen (so a link merely *mentioned* in a chat/feed isn't
     * mistaken for an open in-app browser) PLUS a URL-shaped text node in the top
     * strip of the screen whose host is blocked.
     */
    private fun findBlockedInAppUrl(root: AccessibilityNodeInfo, now: Long): String? {
        val topLimit = (screenHeightPx() * 0.30f).toInt()
        val rect = Rect()
        var hasWebView = false
        var blocked: String? = null
        var firstTopUrl: String? = null

        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 3000) {
            val node = queue.removeFirst()
            visited++
            if (!hasWebView && node.className?.toString() == "android.webkit.WebView") {
                hasWebView = true
            }
            val text = node.text?.toString()
            if (text != null && looksLikeUrl(text)) {
                node.getBoundsInScreen(rect)
                if (rect.top in 0..topLimit) {
                    if (firstTopUrl == null) firstTopUrl = text
                    if (BlockRepository.isBlockedHost(this, text)) blocked = text
                }
            }
            for (i in 0 until node.childCount) {
                val child = try {
                    node.getChild(i)
                } catch (_: Exception) {
                    null
                }
                if (child != null) queue.add(child)
            }
        }

        if (!hasWebView) return null
        if (blocked == null && firstTopUrl != null && now - lastInAppLogAt >= 2000) {
            lastInAppLogAt = now
            Log.d(TAG, "in-app browser top url (not blocked): \"$firstTopUrl\"")
        }
        return blocked
    }

    /** Rough "is this a bare URL/host" test: no spaces, has a dot, sane length. */
    private fun looksLikeUrl(text: String): Boolean {
        val t = text.trim()
        if (t.length < 4 || t.length > 200) return false
        if (t.any { it.isWhitespace() }) return false
        return t.contains('.')
    }

    // ---- In-app feature blocking (Shorts / Reels) ----

    // Feature-blocking maps + detection hints live in BlockCatalog.kt.
    private val featureApps = BlockCatalog.featureApps
    private val featureLabels = BlockCatalog.featureLabels
    private val featureIdHints = BlockCatalog.featureIdHints
    private val featureDescHints = BlockCatalog.featureDescHints

    private fun isFeatureApp(pkg: String): Boolean = featureApps.containsKey(pkg)

    /**
     * True when Instagram's immersive Reels *viewer* is actually on screen — the
     * Reels tab (bottom nav), a reel opened from a DM/message, or a reel from
     * search/explore/feed. It always has BOTH the swipe pager
     * (`clips_viewer_view_pager`) AND the reel action rail (`clips_ufi_component`
     * — like/comment/share). The home feed / reels *tray* (thumbnails) has the
     * pager but NOT the action rail, so browsing the feed is never blocked.
     *
     * BOTH nodes must be **visible on screen** (`isVisibleToUser`). This is the
     * key to killing the reload loop: after you leave Reels, Instagram keeps the
     * *paused* reel fragment in the accessibility tree but marks it not-visible —
     * without this check that lingering fragment kept re-triggering the block on
     * the home/DM screen. (Tuned from real logcat — see details/STEP-4.)
     */
    private fun isReelViewerActive(root: AccessibilityNodeInfo): Boolean {
        var hasPager = false
        var hasUfi = false
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 3000) {
            val node = queue.removeFirst()
            visited++
            val id = node.viewIdResourceName
            if (id != null && node.isVisibleToUser) {
                if (id.contains("clips_viewer_view_pager", ignoreCase = true)) hasPager = true
                if (id.contains("clips_ufi_component", ignoreCase = true)) hasUfi = true
                if (hasPager && hasUfi) return true
            }
            for (i in 0 until node.childCount) {
                val child = try {
                    node.getChild(i)
                } catch (_: Exception) {
                    null
                }
                if (child != null) queue.add(child)
            }
        }
        return false
    }

    /**
     * Handle a Shorts/Reels-blocked app in the foreground. When the player is on
     * screen:
     *  - **direct** mode → a "blocked" screen;
     *  - **timed** mode → allow while a session is running (countdown widget);
     *    with no session but opens left, an interstitial (Open in 5 s spends an
     *    open); with the quota used up, a "resets tomorrow" screen.
     *
     * All the screens are shown via [bounceThenFeatureScreen], which sends Back
     * first (leaving the player, so YouTube can't pop the Short into PiP and
     * strand us on the phone home) and then shows the screen over the app's feed.
     * See details/STEP-4 & STEP-5.
     */
    private fun checkBlockedFeature(pkg: String) {
        if (BlockActivity.isVisible) return
        val key = featureApps[pkg] ?: return
        // If the parent app is itself blocked, the app-level rule already governs
        // it — don't ALSO enforce the in-app feature. A strict app-block never
        // lets you reach the feature anyway; a timed one is already capped by the
        // app's own limit. The feature's config/streak stay frozen on the Flutter
        // side and resurface when the app is unblocked.
        if (BlockRepository.configFor(this, pkg) != null) {
            if (floating.currentPackage == key) floating.hide()
            return
        }
        val cfg = BlockRepository.featureConfigFor(this, key)
        if (cfg == null) {                        // feature off
            if (floating.currentPackage == key) floating.hide()
            return
        }

        val now = SystemClock.uptimeMillis()
        if (now < graceUntil) return
        if (now - lastFeatureCheckAt < 350) return
        lastFeatureCheckAt = now

        val root = try {
            rootInActiveWindow
        } catch (_: Exception) {
            null
        } ?: return

        // Instagram: block whenever the immersive Reels *viewer* is on screen
        // (Reels tab, a reel opened from a DM, or a reel watched in the feed) —
        // NOT the home feed / reels tray. Other apps: view-id / description.
        val onPlayer = if (key == "ig_reels") {
            isReelViewerActive(root)
        } else {
            treeHasSignal(root, featureIdHints[key].orEmpty(), featureDescHints[key].orEmpty())
        }
        if (!onPlayer) {
            // Left the Shorts/Reels player (e.g. back on the feed) — no widget.
            if (floating.currentPackage == key) floating.hide()
            logFeatureCandidates(root, key, now)
            return
        }

        val label = featureLabels[key] ?: "This"

        if (cfg.mode == "timed") {
            if (BlockRepository.sessionMillisLeft(this, key) > 0) {
                floating.show(key)   // session running → allow + countdown widget
                return
            }
            floating.hide()
            if (BlockRepository.opensLeftToday(this, key) > 0) {
                // Opens remain → the "Is this really needed?" interstitial
                // (Open disabled 5 s → spends one open, then re-enter to watch).
                Log.d(TAG, "feature interstitial: $key")
                bounceThenFeatureScreen(key, BlockActivity.MODE_INTERSTITIAL, null)
            } else {
                // Quota used up → a plain "resets tomorrow" block screen.
                Log.d(TAG, "feature quota used up: $key")
                bounceThenFeatureScreen(
                    key,
                    BlockActivity.MODE_BLOCK,
                    "$label\n\nDaily limit reached.\nComes back tomorrow.",
                )
            }
            return
        }

        // Direct block → a plain block screen.
        Log.d(TAG, "blocked feature in $pkg: $key")
        floating.hide()
        bounceThenFeatureScreen(key, BlockActivity.MODE_BLOCK, "$label is blocked.")
    }

    /**
     * Show a block screen for a Shorts/Reels feature WITHOUT the picture-in-
     * picture trap: first send Back to leave the player (this stops playback, so
     * YouTube won't pop the Short into a PiP window and strand us on the phone
     * home), then a beat later show the screen over the app's own feed. The
     * screen is launched with `feature = true`, so its buttons just finish() back
     * to the feed. A grace window covers the transition so nothing re-triggers.
     */
    private fun bounceThenFeatureScreen(key: String, mode: String, reason: String?) {
        graceUntil = SystemClock.uptimeMillis() + 1500
        // Leave the Reels/Shorts player. Instagram (Reels tab → launcher on Back)
        // and YouTube (PiP) exit cleanly by clicking the app's bottom-nav "Home"
        // tab. Facebook does NOT leave its reel on a Home click (it just loops),
        // so use a global Back there. Fall back to Back if no Home tab is found.
        val root = try {
            rootInActiveWindow
        } catch (_: Exception) {
            null
        }
        val leftViaHome = key != "fb_reels" && root != null && clickHomeTab(root)
        if (!leftViaHome) {
            performGlobalAction(GLOBAL_ACTION_BACK)
        }
        pendingBlockLaunch?.let { handler.removeCallbacks(it) }
        val launch = Runnable { launchBlockActivity(key, mode, reason, feature = true) }
        pendingBlockLaunch = launch
        handler.postDelayed(launch, 300L)
    }

    /**
     * Click the app's bottom-nav "Home" tab to leave the Reels/Shorts player
     * while staying in the app. Only considers a clickable node labelled "Home"
     * in the bottom strip (the nav bar). Returns whether it clicked something.
     */
    private fun clickHomeTab(root: AccessibilityNodeInfo): Boolean {
        val bottom = (screenHeightPx() * 0.82f).toInt()
        val rect = Rect()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 3000) {
            val node = queue.removeFirst()
            visited++
            val d = node.contentDescription?.toString()
            if (d != null && d.startsWith("Home", ignoreCase = true)) {
                node.getBoundsInScreen(rect)
                if (rect.top >= bottom) {
                    var n: AccessibilityNodeInfo? = node
                    var depth = 0
                    while (n != null && depth < 6) {
                        if (n.isClickable) {
                            n.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                            Log.d(TAG, "clicked Home tab to leave the player")
                            return true
                        }
                        n = n.parent
                        depth++
                    }
                }
            }
            for (i in 0 until node.childCount) {
                val child = try {
                    node.getChild(i)
                } catch (_: Exception) {
                    null
                }
                if (child != null) queue.add(child)
            }
        }
        return false
    }

    /**
     * Bounded BFS for a node whose view-id contains an [idHints] fragment OR
     * whose content-description contains a [descHints] fragment (case-insensitive).
     */
    private fun treeHasSignal(
        root: AccessibilityNodeInfo,
        idHints: List<String>,
        descHints: List<String>,
    ): Boolean {
        if (idHints.isEmpty() && descHints.isEmpty()) return false
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 2500) {
            val node = queue.removeFirst()
            visited++
            if (idHints.isNotEmpty()) {
                val id = node.viewIdResourceName
                if (id != null && idHints.any { id.contains(it, ignoreCase = true) }) return true
            }
            if (descHints.isNotEmpty()) {
                val d = node.contentDescription?.toString()
                if (d != null && descHints.any { d.contains(it, ignoreCase = true) }) return true
            }
            for (i in 0 until node.childCount) {
                val child = try {
                    node.getChild(i)
                } catch (_: Exception) {
                    null
                }
                if (child != null) queue.add(child)
            }
        }
        return false
    }

    /** Print candidate view-ids + content-descriptions so detection can be tuned. */
    private fun logFeatureCandidates(root: AccessibilityNodeInfo, key: String, now: Long) {
        if (now - lastCandidateLogAt < 2000) return
        lastCandidateLogAt = now

        val idKeywords = listOf("reel", "short", "clip", "video", "watch", "story", "player")
        val descKeywords = listOf("reel", "short", "clip", "swipe", "video", "watch", "story", "selected")
        val ids = LinkedHashSet<String>()
        val descs = LinkedHashSet<String>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < 3000 && ids.size < 40) {
            val node = queue.removeFirst()
            visited++
            node.viewIdResourceName?.let { id ->
                if (idKeywords.any { id.contains(it, ignoreCase = true) }) {
                    ids.add(id.substringAfterLast('/'))
                }
            }
            node.contentDescription?.toString()?.let { d ->
                if (d.length in 1..30 && descKeywords.any { d.contains(it, ignoreCase = true) }) {
                    descs.add(d)
                }
            }
            for (i in 0 until node.childCount) {
                val child = try {
                    node.getChild(i)
                } catch (_: Exception) {
                    null
                }
                if (child != null) queue.add(child)
            }
        }
        if (ids.isNotEmpty() || descs.isNotEmpty()) {
            Log.d(TAG, "feature candidates ($key): ids=$ids descs=$descs")
        }
    }

    // ---- Floating session widget (built in FloatingWidget.kt) ----
    private val floating by lazy { FloatingWidget(this, handler, ::onFloatingRelock) }

    /**
     * Relock button on the floating widget: end the session, hide the widget,
     * then get out of the way — for a feature leave the player (so a new session
     * doesn't auto-start on the same screen), otherwise re-evaluate the now-
     * blocked app.
     */
    private fun onFloatingRelock(pkg: String) {
        BlockRepository.endSession(this, pkg)
        floating.hide()
        if (BlockCatalog.featureLabels.containsKey(pkg)) {
            graceUntil = SystemClock.uptimeMillis() + 1500
            val r = try {
                rootInActiveWindow
            } catch (_: Exception) {
                null
            }
            if (r == null || !clickHomeTab(r)) performGlobalAction(GLOBAL_ACTION_BACK)
        } else {
            evaluate()
        }
    }

    private fun screenWidthPx(): Int = resources.displayMetrics.widthPixels

    private fun screenHeightPx(): Int = resources.displayMetrics.heightPixels

}
