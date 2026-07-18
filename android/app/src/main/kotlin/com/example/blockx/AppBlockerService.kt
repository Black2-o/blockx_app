package com.example.blockx

import android.accessibilityservice.AccessibilityService
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

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
    private val ignoredPackages = setOf(
        "com.android.systemui",
        "com.google.android.play.games",
        "com.google.android.gms",
        "com.oplus.games",
        "com.oplus.gamespace",
        "com.coloros.gamespaceui",
        "com.coloros.gamespace",
        "com.coloros.gameassistant",
        "com.nearme.gamecenter",
    )

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
        hideFloating()
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
            hideFloating()
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
                    hideFloating()
                }
            }

            BlockRepository.Decision.ALLOW_SESSION -> showFloating(pkg)

            BlockRepository.Decision.INTERSTITIAL -> {
                hideFloating()
                showBlockScreen(pkg, BlockActivity.MODE_INTERSTITIAL, null)
            }

            BlockRepository.Decision.BLOCK -> {
                hideFloating()
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

    // Known browsers whose address bar we watch. Most Chromium browsers expose
    // the URL under an "url_bar" id; the others use their own toolbar ids.
    private val browserPackages = setOf(
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "com.chrome.canary",
        "com.brave.browser",
        "com.brave.browser_beta",
        "com.microsoft.emmx",            // Edge
        "com.opera.browser",
        "com.opera.gx",
        "com.opera.mini.native",
        "com.sec.android.app.sbrowser",  // Samsung Internet
        "com.vivaldi.browser",
        "com.kiwibrowser.browser",
        "com.duckduckgo.mobile.android",
        "org.mozilla.firefox",
        "org.mozilla.focus",
        "com.mi.globalbrowser",
        "com.heytap.browser",            // realme/Oppo browser
        "com.coloros.browser",
        "com.UCMobile.intl",
    )

    // Candidate resource-id suffixes for the address bar, tried in order.
    private val urlBarIdSuffixes = listOf(
        "url_bar",                        // Chrome/Brave/Edge/Vivaldi/Kiwi/...
        "location_bar_edit_text",         // Samsung Internet
        "url_field",                      // Opera
        "mozac_browser_toolbar_url_view", // Firefox
        "omnibarTextInput",               // DuckDuckGo
        "search_box",                     // some OEM browsers
        "address",                        // fallback
    )

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
    private val inAppBrowserHosts = setOf(
        "com.facebook.orca",       // Messenger
        "com.facebook.mlite",      // Messenger Lite
        "com.facebook.katana",     // Facebook
        "com.facebook.lite",       // Facebook Lite
        "com.instagram.android",   // Instagram
        "com.whatsapp",            // WhatsApp
        "com.twitter.android",     // X / Twitter
        "com.snapchat.android",
        "com.reddit.frontpage",
        "com.linkedin.android",
        "org.telegram.messenger",
        "com.google.android.gm",   // Gmail
    )

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

    private val featureApps = mapOf(
        "com.google.android.youtube" to "yt_shorts",
        "com.instagram.android" to "ig_reels",
        "com.facebook.katana" to "fb_reels",
    )

    private val featureLabels = mapOf(
        "yt_shorts" to "YouTube Shorts",
        "ig_reels" to "Instagram Reels",
        "fb_reels" to "Facebook Reels",
    )

    // Player-specific view-id fragments (matched as case-insensitive substrings),
    // kept narrow so the normal feed / a Shorts shelf / an inline reel preview
    // doesn't trigger. Tuned from real logcat (logFeatureCandidates).
    private val featureIdHints = mapOf(
        "yt_shorts" to listOf("reel_recycler", "reel_player", "reel_watch", "shorts_player"),
        // Only the full-screen Reels swipe pager — an inline reel in a DM/feed
        // lacks the pager, so viewing a chat doesn't get blocked.
        "ig_reels" to listOf("clips_viewer_view_pager"),
    )

    // Content-description signals, for apps that expose no useful view-ids.
    // Facebook obfuscates every id, so its Reels surface is identified by these
    // ("Search reels" header + the immersive "…swipe up to see more" reel), which
    // do NOT appear on the normal feed or the bottom-nav Reels tab button.
    private val featureDescHints = mapOf(
        // Facebook has TWO reels entry points:
        //  - the BOTTOM-nav reels feed (you're watching) → "search reels" catches
        //    it immediately;
        //  - the TOP reels *tab list* after stories (just browsing thumbnails) →
        //    identified by "Selected Reels tab" / "tab 2 of 6"; this must NOT be
        //    blocked, so we deliberately do NOT match "selected reels tab".
        // Watching an actual reel (from either, or Messenger) → "reel details"
        // (immediate) / "swipe up to see more" (delayed backup).
        // The top list has neither "search reels" nor "reel details", so it's
        // left alone; the home/stories don't match any of these either.
        "fb_reels" to listOf("search reels", "reel details", "swipe up to see more"),
    )

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
        val cfg = BlockRepository.featureConfigFor(this, key)
        if (cfg == null) {                        // feature off
            if (floatingPackage == key) hideFloating()
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
            if (floatingPackage == key) hideFloating()
            logFeatureCandidates(root, key, now)
            return
        }

        val label = featureLabels[key] ?: "This"

        if (cfg.mode == "timed") {
            if (BlockRepository.sessionMillisLeft(this, key) > 0) {
                showFloating(key)   // session running → allow + countdown widget
                return
            }
            hideFloating()
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
        hideFloating()
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

    // ---- Floating session widget ----

    private var floatingView: View? = null
    private var floatingParams: WindowManager.LayoutParams? = null
    private var floatingIcon: View? = null
    private var floatingPanel: View? = null
    private var floatingPackage: String? = null
    private var floatingExpanded = false
    private var floatingOpensText: TextView? = null
    private var floatingTimeText: TextView? = null

    // Remembered position between rebuilds: which side edge it's parked on and
    // its vertical offset. Starts parked on the right (matching the old fixed
    // spot). -1 y means "not placed yet — use the default".
    private var floatingIsLeftEdge = false
    private var floatingY = -1

    // Drag state for the touch handler (tap = expand, drag = move + snap).
    private var dragStartRawX = 0f
    private var dragStartRawY = 0f
    private var dragStartX = 0
    private var dragStartY = 0
    private var dragMoved = false

    private fun showFloating(pkg: String) {
        if (floatingView != null && floatingPackage == pkg) {
            refreshFloating()
            return
        }
        hideFloating()

        val wm = getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
        val view = buildFloatingView(pkg)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        // Absolute positioning from the top-left corner so the widget can be
        // dragged freely and snapped to whichever side edge is nearest.
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = if (floatingY >= 0) floatingY else dp(120)

        try {
            wm.addView(view, params)
            floatingView = view
            floatingParams = params
            floatingPackage = pkg
            floatingExpanded = false
            attachDragHandler()
            // Width is only known after layout; park it on the remembered edge.
            view.post { placeAtRememberedEdge() }
        } catch (_: Exception) {
        }
    }

    private fun buildFloatingView(pkg: String): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val icon = ImageView(this).apply {
            setImageDrawable(
                try {
                    // Always show BlockX's own icon, never the blocked app's.
                    packageManager.getApplicationIcon(packageName)
                } catch (_: Exception) {
                    null
                },
            )
            val size = dp(44)
            layoutParams = LinearLayout.LayoutParams(size, size)
            // No background/padding — show only the icon, no dark box around it.
        }

        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            visibility = View.GONE
            setBackgroundColor(Color.argb(220, 0, 0, 0))
            setPadding(dp(12), dp(8), dp(12), dp(8))
        }
        val opens = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        }
        val time = TextView(this).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
        }
        val endNow = Button(this).apply {
            text = "End now"
            setOnClickListener {
                BlockRepository.endSession(this@AppBlockerService, pkg)
                hideFloating()
                if (featureLabels.containsKey(pkg)) {
                    // A feature (Shorts/Reels): leave the player so a new session
                    // doesn't immediately auto-start on the same screen.
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
        }
        panel.addView(opens)
        panel.addView(time)
        panel.addView(endNow)

        floatingOpensText = opens
        floatingTimeText = time
        floatingIcon = icon
        floatingPanel = panel

        // Fixed child order: panel then icon (we never mutate the live overlay's
        // hierarchy — that caused a null-child insets crash). anchorToEdge()
        // repositions the whole row against the parked edge so it stays
        // on-screen when the panel expands.
        row.addView(panel)
        row.addView(icon)
        return row
    }

    /** Drag to move, release to snap to the nearest side edge; tap = expand. */
    @android.annotation.SuppressLint("ClickableViewAccessibility")
    private fun attachDragHandler() {
        val icon = floatingIcon ?: return
        val slop = ViewConfiguration.get(this).scaledTouchSlop
        icon.setOnTouchListener { _, event ->
            val params = floatingParams ?: return@setOnTouchListener false
            val view = floatingView ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragStartRawX = event.rawX
                    dragStartRawY = event.rawY
                    dragStartX = params.x
                    dragStartY = params.y
                    dragMoved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = event.rawX - dragStartRawX
                    val dy = event.rawY - dragStartRawY
                    if (!dragMoved &&
                        (Math.abs(dx) > slop || Math.abs(dy) > slop)
                    ) {
                        dragMoved = true
                    }
                    if (dragMoved) {
                        params.x = dragStartX + dx.toInt()
                        params.y = (dragStartY + dy.toInt()).coerceAtLeast(0)
                        updateLayout(view, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragMoved) snapToNearestEdge() else toggleFloatingPanel()
                    true
                }
                else -> false
            }
        }
    }

    /** Place on the remembered edge (used when the widget is (re)shown). */
    private fun placeAtRememberedEdge() {
        val view = floatingView ?: return
        val params = floatingParams ?: return
        val maxY = (screenHeightPx() - view.height).coerceAtLeast(0)
        params.y = (if (floatingY >= 0) floatingY else dp(120)).coerceIn(0, maxY)
        floatingY = params.y
        anchorToEdge()
        updateLayout(view, params)
    }

    /** After a drag, snap to the closer side edge and remember it. */
    private fun snapToNearestEdge() {
        val view = floatingView ?: return
        val params = floatingParams ?: return
        val center = params.x + view.width / 2
        floatingIsLeftEdge = center < screenWidthPx() / 2
        val maxY = (screenHeightPx() - view.height).coerceAtLeast(0)
        params.y = params.y.coerceIn(0, maxY)
        floatingY = params.y
        anchorToEdge()
        updateLayout(view, params)
    }

    /** Pin x flush against the parked edge, using the widget's current width. */
    private fun anchorToEdge() {
        val view = floatingView ?: return
        val params = floatingParams ?: return
        params.x = if (floatingIsLeftEdge) 0 else (screenWidthPx() - view.width).coerceAtLeast(0)
    }

    private fun updateLayout(view: View, params: WindowManager.LayoutParams) {
        try {
            (getSystemService(Context.WINDOW_SERVICE) as? WindowManager)
                ?.updateViewLayout(view, params)
        } catch (_: Exception) {
        }
    }

    private fun screenWidthPx(): Int = resources.displayMetrics.widthPixels

    private fun screenHeightPx(): Int = resources.displayMetrics.heightPixels

    private fun toggleFloatingPanel() {
        floatingExpanded = !floatingExpanded
        floatingPanel?.visibility = if (floatingExpanded) View.VISIBLE else View.GONE
        refreshFloating()
        // The panel changes the widget's width; re-pin it to the parked edge
        // once the new size is measured so it never runs off-screen.
        val view = floatingView ?: return
        view.post {
            anchorToEdge()
            floatingParams?.let { updateLayout(view, it) }
        }
    }

    private fun refreshFloating() {
        val pkg = floatingPackage ?: return
        if (!floatingExpanded) return
        val opensLeft = BlockRepository.opensLeftToday(this, pkg)
        val msLeft = BlockRepository.sessionMillisLeft(this, pkg)
        val mins = (msLeft / 60_000L).toInt()
        val secs = ((msLeft % 60_000L) / 1000L).toInt()
        floatingOpensText?.text = "Opens left today: $opensLeft"
        floatingTimeText?.text = "Time left: %d:%02d".format(mins, secs)
    }

    private fun hideFloating() {
        val view = floatingView ?: return
        try {
            (getSystemService(Context.WINDOW_SERVICE) as? WindowManager)?.removeView(view)
        } catch (_: Exception) {
        }
        floatingView = null
        floatingParams = null
        floatingIcon = null
        floatingPanel = null
        floatingPackage = null
        floatingExpanded = false
        floatingOpensText = null
        floatingTimeText = null
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics,
    ).toInt()
}
