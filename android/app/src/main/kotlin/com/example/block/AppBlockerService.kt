package com.example.block

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
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

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

        when (BlockRepository.decide(this, pkg)) {
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
        // foreground, winning the race against our block screen and flickering
        // back into view. If the SAME app keeps reappearing within a few seconds,
        // decisively send it to the background with HOME first — an app cannot win
        // against the global Home action. Normal apps/games block on the first try
        // and never hit this, so they don't get an extra launcher flash.
        if (pkg == lastBlockedPackage && now - lastBlockStart < 4000) {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
        lastBlockStart = now
        lastBlockedPackage = pkg

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
        } catch (_: Exception) {
        }
    }

    // ---- Floating session widget ----

    private var floatingView: View? = null
    private var floatingPackage: String? = null
    private var floatingExpanded = false
    private var floatingOpensText: TextView? = null
    private var floatingTimeText: TextView? = null

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
        params.gravity = Gravity.TOP or Gravity.END
        params.y = dp(120)

        try {
            wm.addView(view, params)
            floatingView = view
            floatingPackage = pkg
            floatingExpanded = false
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
                    packageManager.getApplicationIcon(pkg)
                } catch (_: Exception) {
                    null
                },
            )
            val size = dp(44)
            layoutParams = LinearLayout.LayoutParams(size, size)
            setBackgroundColor(Color.argb(160, 0, 0, 0))
            setPadding(dp(4), dp(4), dp(4), dp(4))
            setOnClickListener { toggleFloatingPanel() }
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

        row.addView(panel)
        row.addView(icon)
        return row
    }

    private fun toggleFloatingPanel() {
        floatingExpanded = !floatingExpanded
        val panel = (floatingView as? LinearLayout)?.getChildAt(0)
        panel?.visibility = if (floatingExpanded) View.VISIBLE else View.GONE
        refreshFloating()
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
        floatingPackage = null
        floatingExpanded = false
        floatingOpensText = null
        floatingTimeText = null
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics,
    ).toInt()
}
