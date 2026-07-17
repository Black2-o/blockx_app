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

    @Volatile
    private var currentForegroundPackage: String? = null

    private var lastBlockStart = 0L
    private var lastBlockedPackage: String? = null
    private var pendingBlockLaunch: Runnable? = null
    private var lastDecisionKey: String? = null
    private var usageStatsManager: UsageStatsManager? = null

    private val handler = Handler(Looper.getMainLooper())
    private val recheckIntervalMs = 350L

    private val recheckRunnable = object : Runnable {
        override fun run() {
            pollForegroundApp()
            evaluate()
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
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkg = event.packageName?.toString()
        if (pkg.isNullOrEmpty()) return

        // Ignore assistant/side-panel windows, and our own windows (our floating
        // widget must not be mistaken for a foreground app switch). UsageStats
        // reports our real activities when they matter.
        if (isIgnoredPackage(pkg) || pkg == packageName) return

        currentForegroundPackage = pkg
        evaluate()
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
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
            BlockRepository.Decision.NONE -> hideFloating()

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

    private fun launchBlockActivity(pkg: String, mode: String, reason: String?) {
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
        }
        try {
            startActivity(intent)
            Log.d(TAG, "launched BlockActivity for $pkg")
        } catch (e: Exception) {
            Log.w(TAG, "failed to launch BlockActivity for $pkg", e)
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
                evaluate()
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
