package com.example.blockx

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.os.CountDownTimer
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

private const val TAG = "BlockX"

/**
 * The full-screen screen shown over a blocked app. Two modes:
 *  - MODE_BLOCK: plain "This app is blocked." + Go home (direct apps, or a timed
 *    app whose daily opens are used up).
 *  - MODE_INTERSTITIAL: "Is this really needed?" + Go home + Open. Open is
 *    disabled for 5s, then tapping it spends one daily open, starts the timed
 *    session, and re-launches the app.
 *
 * It's a real Activity (not an overlay) so the blocked app is pushed to the
 * background and actually pauses. See [AppBlockerService].
 */
class BlockActivity : Activity() {

    companion object {
        @Volatile
        var isVisible: Boolean = false
            private set

        const val EXTRA_PACKAGE = "package"
        const val EXTRA_MODE = "mode"
        const val EXTRA_REASON = "reason"
        /** Shorts/Reels flavour: buttons just finish() back to the app's feed. */
        const val EXTRA_FEATURE = "feature"
        const val MODE_BLOCK = "block"
        const val MODE_INTERSTITIAL = "interstitial"
        const val MODE_BACK = "back"

        private const val OPEN_DELAY_MS = 5_000L
    }

    private var blockedPackage: String? = null
    private var openButton: Button? = null
    private var countdown: CountDownTimer? = null
    private var isBackMode = false
    private var isFeature = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        render(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        render(intent)
    }

    private fun render(intent: Intent?) {
        blockedPackage = intent?.getStringExtra(EXTRA_PACKAGE)
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: MODE_BLOCK
        val reason = intent?.getStringExtra(EXTRA_REASON)
        isBackMode = mode == MODE_BACK
        isFeature = intent?.getBooleanExtra(EXTRA_FEATURE, false) ?: false
        setContentView(
            when (mode) {
                MODE_INTERSTITIAL -> buildInterstitial()
                MODE_BACK -> buildBackBlock(reason)
                else -> buildBlock(reason)
            },
        )
    }

    // ---- Plain block ----

    private fun buildBlock(reason: String?): View {
        val root = container()
        root.addView(
            text(reason ?: "This app is blocked.", 22f),
        )
        root.addView(spacer())
        root.addView(
            button(if (isFeature) "Go back" else "Go to home screen") { leaveToHome() },
        )
        return root
    }

    // ---- "Back" block (close returns to where you were, not the phone home) ----
    // Used for blocked websites and in-app browsers: the service sends a global
    // BACK so you return to the browser's home / previous tab, not the phone
    // home. (Shorts/Reels use MODE_BLOCK/MODE_INTERSTITIAL with EXTRA_FEATURE
    // instead — the service already backed out of the player before showing it.)

    private fun buildBackBlock(reason: String?): View {
        val root = container()
        root.addView(text(reason ?: "This is blocked.", 22f))
        root.addView(spacer())
        root.addView(button("Go back") { goBack() })
        return root
    }

    private fun goBack() {
        AppBlockerService.instance?.goBackAndPause()
        finish()
    }

    // ---- Interstitial with delayed Open ----

    private fun buildInterstitial(): View {
        val root = container()
        root.addView(text("Is this really needed?", 22f))

        val pkg = blockedPackage
        if (pkg != null) {
            val left = BlockRepository.opensLeftToday(this, pkg)
            root.addView(text("Opens left today: $left", 15f))
        }

        root.addView(spacer())

        val open = Button(this).apply {
            text = "Open (5)"
            isEnabled = false
            setOnClickListener { onOpenTapped() }
        }
        openButton = open
        root.addView(open)

        root.addView(spacer())
        root.addView(
            button(if (isFeature) "Not now" else "Go to home screen") { leaveToHome() },
        )

        startOpenCountdown()
        return root
    }

    private fun startOpenCountdown() {
        countdown?.cancel()
        countdown = object : CountDownTimer(OPEN_DELAY_MS, 1_000L) {
            override fun onTick(msLeft: Long) {
                val secs = (msLeft / 1000L).toInt() + 1
                openButton?.text = "Open ($secs)"
            }

            override fun onFinish() {
                openButton?.text = "Open"
                openButton?.isEnabled = true
            }
        }.start()
    }

    private fun onOpenTapped() {
        val pkg = blockedPackage ?: return
        BlockRepository.startSession(this, pkg)
        // Re-launch the app; the service will now see an active session and allow
        // it (and show the floating widget) instead of blocking.
        val launch = packageManager.getLaunchIntentForPackage(pkg)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(launch)
        }
        finish()
    }

    // ---- Shared ----

    private fun leaveToHome() {
        // Feature (Shorts/Reels) screens are shown over the app's own feed (the
        // service backed out of the player first), so just return there — NOT the
        // phone home screen.
        if (isFeature) {
            finish()
            return
        }
        Log.d(TAG, "leaveToHome (Go to home button) pkg=$blockedPackage")
        startActivity(
            Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
        finish()
    }

    @Deprecated("Back should leave, not return to the blocked app/site")
    override fun onBackPressed() {
        when {
            isFeature -> finish()
            isBackMode -> goBack()
            else -> leaveToHome()
        }
    }

    override fun onResume() {
        super.onResume()
        isVisible = true
    }

    override fun onStop() {
        super.onStop()
        isVisible = false
        countdown?.cancel()
        finish()
    }

    // ---- tiny view helpers (plain, no XML) ----

    private fun container(): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(Color.BLACK)
        setPadding(dp(24), dp(24), dp(24), dp(24))
    }

    private fun text(value: String, sizeSp: Float): TextView = TextView(this).apply {
        text = value
        setTextColor(Color.WHITE)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        gravity = Gravity.CENTER
    }

    private fun button(label: String, onClick: () -> Unit): Button = Button(this).apply {
        text = label
        setOnClickListener { onClick() }
    }

    private fun spacer(): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(16),
        )
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics,
    ).toInt()
}
