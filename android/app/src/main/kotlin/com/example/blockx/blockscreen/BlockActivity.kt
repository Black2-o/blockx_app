package com.example.blockx.blockscreen

import com.example.blockx.R
import com.example.blockx.blocking.AppBlockerService
import com.example.blockx.blocking.BlockRepository
import com.example.blockx.common.BlockCatalog
import com.example.blockx.common.BlockPalette

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.CountDownTimer
import android.util.Log
import android.view.View
import android.widget.Button
import android.widget.LinearLayout

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
 *
 * This file owns the *logic* (modes, extras, countdown, session, repository
 * calls); all the styled view building lives in [BlockScreenViews].
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

    // Accents (single source of truth: BlockPalette.kt).
    private val cRed = BlockPalette.red
    private val cAmber = BlockPalette.amber

    private val views by lazy { BlockScreenViews(this) }

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
        val root = views.container(cRed)
        root.addView(views.flexSpacer())
        root.addView(
            views.iconBadge(
                cRed,
                if (isFeature) R.drawable.ic_block_feature else R.drawable.ic_block_lock,
            ),
        )
        root.addView(views.spacer(views.dp(24)))
        root.addView(views.headline(if (isFeature) "Blocked" else "App Blocked"))
        root.addView(views.spacer(views.dp(12)))
        root.addView(views.bodyText(reason ?: "This app is blocked."))
        val pkg = blockedPackage
        if (pkg != null) {
            // Timed apps/features that ran out of opens: show the (empty) count +
            // dots too, so every timer-blocked screen looks the same.
            addOpensStatus(root, pkg, cRed, showName = false)
            addStreak(root, pkg, cRed)
        }
        root.addView(views.flexSpacer(2f))
        root.addView(
            views.primaryButton(
                if (isFeature) "Go back" else "Go to home screen",
                cRed,
            ) { leaveToHome() },
        )
        return root
    }

    // ---- "Back" block (close returns to where you were, not the phone home) ----
    // Used for blocked websites and in-app browsers: the service sends a global
    // BACK so you return to the browser's home / previous tab, not the phone
    // home. (Shorts/Reels use MODE_BLOCK/MODE_INTERSTITIAL with EXTRA_FEATURE
    // instead — the service already backed out of the player before showing it.)

    private fun buildBackBlock(reason: String?): View {
        val root = views.container(cRed)
        root.addView(views.flexSpacer())
        root.addView(views.iconBadge(cRed, R.drawable.ic_block_globe))
        root.addView(views.spacer(views.dp(24)))
        root.addView(views.headline("Site Blocked"))
        root.addView(views.spacer(views.dp(12)))
        root.addView(views.bodyText(reason ?: "This is blocked."))
        root.addView(views.flexSpacer(2f))
        root.addView(views.primaryButton("Go back", cRed) { goBack() })
        return root
    }

    private fun goBack() {
        AppBlockerService.instance?.goBackAndPause()
        finish()
    }

    // ---- Interstitial with delayed Open ----

    private fun buildInterstitial(): View {
        val root = views.container(cAmber)
        root.addView(views.flexSpacer())
        // The blocked app's own icon, ringed in amber, with a small hourglass
        // state chip — contextual, so you see exactly what you're about to open.
        root.addView(views.appBadge(blockedPackage, cAmber, isFeature))
        root.addView(views.spacer(views.dp(30)))
        root.addView(views.headline("Is this really needed?"))

        val pkg = blockedPackage
        if (pkg != null) {
            root.addView(views.spacer(views.dp(10)))
            root.addView(views.appNameLine(displayName(pkg), cAmber))
            // A calm "opens left today" group: overline · "X of Y left" · dots.
            addInterstitialOpens(root, pkg, cAmber)
        }

        root.addView(views.flexSpacer(2f))

        val open = views.primaryButton("Open now (5)", cAmber) { onOpenTapped() }.apply {
            isEnabled = false
        }
        openButton = open
        root.addView(open)

        root.addView(views.spacer(views.dp(10)))
        root.addView(
            views.secondaryLink(if (isFeature) "Not now" else "Go to home screen") {
                leaveToHome()
            },
        )

        startOpenCountdown()
        return root
    }

    /**
     * The interstitial's "opens left today" group: a dim overline, an
     * "X of Y left" line (the count in the accent), then the opens dots — each
     * generously spaced so the screen reads calm, not packed. No-op for
     * direct-blocked items.
     */
    private fun addInterstitialOpens(root: LinearLayout, id: String, accent: Int) {
        if (!BlockRepository.isTimed(this, id)) return
        val left = BlockRepository.opensLeftToday(this, id)
        val used = BlockRepository.opensUsedToday(this, id)
        val total = left + used

        root.addView(views.spacer(views.dp(34)))
        root.addView(views.overlineLabel("Opens left today"))
        root.addView(views.spacer(views.dp(10)))
        root.addView(views.opensCountLine(left, total, accent))
        if (total in 1..12) {
            root.addView(views.spacer(views.dp(14)))
            root.addView(views.opensDots(left, total, accent))
        }
    }

    /** The blocked app's name, or a human label for a feature key. */
    private fun displayName(pkg: String?): String {
        if (pkg == null) return "This app"
        BlockCatalog.featureLabels[pkg]?.let { return it }
        return try {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(pkg, 0),
            ).toString()
        } catch (_: Exception) {
            "This app"
        }
    }

    /**
     * For a timed app/feature only: a "left/total" line plus the opens dots.
     * [showName] prefixes the item's name (used on the interstitial, where the
     * headline doesn't already name it). No-op for direct-blocked items.
     */
    private fun addOpensStatus(
        root: LinearLayout,
        id: String,
        accent: Int,
        showName: Boolean,
    ) {
        if (!BlockRepository.isTimed(this, id)) return
        val left = BlockRepository.opensLeftToday(this, id)
        val used = BlockRepository.opensUsedToday(this, id)
        val total = left + used
        root.addView(views.spacer(views.dp(16)))
        val prefix = if (showName) "${displayName(id)}   " else ""
        root.addView(views.bodyText("$prefix$left/$total left"))
        if (total in 1..12) {
            root.addView(views.spacer(views.dp(12)))
            root.addView(views.opensDots(left, total, accent))
        }
    }

    /** A "N days blocked" streak line, if this app/feature has a live streak. */
    private fun addStreak(root: LinearLayout, id: String, accent: Int) {
        val days = BlockRepository.streakDays(this, id)
        if (days <= 0) return
        root.addView(views.spacer(views.dp(16)))
        root.addView(views.streakLine(days, accent))
    }

    private fun startOpenCountdown() {
        countdown?.cancel()
        countdown = object : CountDownTimer(OPEN_DELAY_MS, 1_000L) {
            override fun onTick(msLeft: Long) {
                val secs = (msLeft / 1000L).toInt() + 1
                openButton?.text = "Open now ($secs)"
            }

            override fun onFinish() {
                openButton?.text = "Open now"
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
}
