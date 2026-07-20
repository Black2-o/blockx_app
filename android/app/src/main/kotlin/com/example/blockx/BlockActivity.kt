package com.example.blockx

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
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
 *
 * NOTE: this file's *logic* (modes, extras, countdown, session, repository
 * calls) is frozen. Only the view-builder helpers below were restyled to match
 * the BlockX visual language (details/ui-redesign/03-SCREENS-SPEC.md).
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

    // ---- BlockX palette (matches lib/theme/app_colors.dart) ----
    private val cDark = 0xFF080808.toInt()
    private val cRed = 0xFFE8000D.toInt()
    private val cAmber = 0xFFFFB020.toInt()
    private val cText = 0xFFF0E0E0.toInt()
    private val cWhite = 0xFFFFFFFF.toInt()
    private val cDim = 0x80F0C8C8.toInt()

    // ---- Bundled fonts (loaded from Flutter assets; null-safe fallback) ----
    private val oswald600 by lazy { font("flutter_assets/assets/fonts/Oswald-SemiBold.ttf") }
    private val oswald400 by lazy { font("flutter_assets/assets/fonts/Oswald-Regular.ttf") }
    private val barlow by lazy { font("flutter_assets/assets/fonts/BarlowCondensed-Regular.ttf") }

    private var blockedPackage: String? = null
    private var openButton: Button? = null
    private var countdown: CountDownTimer? = null
    private var isBackMode = false
    private var isFeature = false

    // Human labels for feature keys (the interstitial's EXTRA_PACKAGE is a feature
    // key like "ig_reels", not a real package). Kept in sync with AppBlockerService.
    private val featureLabels = mapOf(
        "yt_shorts" to "YouTube Shorts",
        "ig_reels" to "Instagram Reels",
        "fb_reels" to "Facebook Reels",
    )

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
        val root = container(cRed)
        root.addView(flexSpacer())
        root.addView(iconBadge(cRed, if (isFeature) R.drawable.ic_block_feature else R.drawable.ic_block_lock))
        root.addView(spacer(dp(24)))
        root.addView(headline(if (isFeature) "Blocked" else "App Blocked"))
        root.addView(spacer(dp(12)))
        root.addView(bodyText(reason ?: "This app is blocked."))
        val pkg = blockedPackage
        if (pkg != null) {
            // Timed apps/features that ran out of opens: show the (empty) count +
            // dots too, so every timer-blocked screen looks the same.
            addOpensStatus(root, pkg, cRed, showName = false)
            addStreak(root, pkg)
        }
        root.addView(flexSpacer())
        root.addView(
            primaryButton(if (isFeature) "Go back" else "Go to home screen", cRed) { leaveToHome() },
        )
        return root
    }

    // ---- "Back" block (close returns to where you were, not the phone home) ----
    // Used for blocked websites and in-app browsers: the service sends a global
    // BACK so you return to the browser's home / previous tab, not the phone
    // home. (Shorts/Reels use MODE_BLOCK/MODE_INTERSTITIAL with EXTRA_FEATURE
    // instead — the service already backed out of the player before showing it.)

    private fun buildBackBlock(reason: String?): View {
        val root = container(cRed)
        root.addView(flexSpacer())
        root.addView(iconBadge(cRed, R.drawable.ic_block_globe))
        root.addView(spacer(dp(24)))
        root.addView(headline("Site Blocked"))
        root.addView(spacer(dp(12)))
        root.addView(bodyText(reason ?: "This is blocked."))
        root.addView(flexSpacer())
        root.addView(primaryButton("Go back", cRed) { goBack() })
        return root
    }

    private fun goBack() {
        AppBlockerService.instance?.goBackAndPause()
        finish()
    }

    // ---- Interstitial with delayed Open ----

    private fun buildInterstitial(): View {
        val root = container(cAmber)
        root.addView(flexSpacer())
        root.addView(iconBadge(cAmber, R.drawable.ic_block_hourglass))
        root.addView(spacer(dp(24)))
        root.addView(headline("Is this really needed?"))

        val pkg = blockedPackage
        if (pkg != null) {
            addOpensStatus(root, pkg, cAmber, showName = true)
            addStreak(root, pkg)
        }

        root.addView(flexSpacer())

        val open = primaryButton("Open now (5)", cAmber) { onOpenTapped() }.apply {
            isEnabled = false
        }
        openButton = open
        root.addView(open)

        root.addView(spacer(dp(4)))
        root.addView(
            secondaryLink(if (isFeature) "Not now" else "Go to home screen") { leaveToHome() },
        )

        startOpenCountdown()
        return root
    }

    /** The blocked app's name, or a human label for a feature key. */
    private fun displayName(pkg: String?): String {
        if (pkg == null) return "This app"
        featureLabels[pkg]?.let { return it }
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
        root.addView(spacer(dp(16)))
        val prefix = if (showName) "${displayName(id)}   " else ""
        root.addView(bodyText("$prefix$left/$total left"))
        if (total in 1..12) {
            root.addView(spacer(dp(12)))
            root.addView(opensDots(left, total, accent))
        }
    }

    /** A "N days blocked" streak line, if this app/feature has a live streak. */
    private fun addStreak(root: LinearLayout, id: String) {
        val days = BlockRepository.streakDays(this, id)
        if (days <= 0) return
        root.addView(spacer(dp(16)))
        root.addView(streakLine(days))
    }

    private fun streakLine(days: Int): TextView {
        val noun = if (days == 1) "day" else "days"
        return TextView(this).apply {
            text = "🔥  $days $noun blocked"
            setTextColor(cAmber)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            letterSpacing = 0.04f
            typeface = oswald600 ?: Typeface.DEFAULT_BOLD
        }
    }

    /**
     * A horizontal row of dots for the daily opens: a filled dot for each open
     * still remaining, a hollow ring for each already used.
     */
    private fun opensDots(left: Int, total: Int, accent: Int): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val size = dp(13)
        val gap = dp(6)
        for (i in 0 until total) {
            val filled = i < left
            val dot = View(this).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    if (filled) {
                        setColor(accent)
                    } else {
                        setColor(0x00000000)
                        setStroke(dp(2), withAlpha(accent, 0x66))
                    }
                }
                layoutParams = LinearLayout.LayoutParams(size, size).apply {
                    marginStart = if (i == 0) 0 else gap
                }
            }
            row.addView(dot)
        }
        return row
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

    // ---- styled view helpers (BlockX visual language, no XML) ----

    /** Root: full-height column on the dark background with a soft radial glow.
     *  Content is centered by flex spacers; the action button sits at the bottom. */
    @Suppress("DEPRECATION")
    private fun container(accent: Int): LinearLayout = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        background = glow(accent)
        val padH = dp(28)
        val padTop = dp(28)
        val padBottom = dp(40)
        setPadding(padH, padTop, padH, padBottom)
        // Keep the bottom action clear of the system nav bar / gesture pill (and
        // content clear of the status bar) — on some OEMs the block screen draws
        // edge-to-edge, so a fixed bottom padding left the button under the nav.
        setOnApplyWindowInsetsListener { v, insets ->
            val top: Int
            val bottom: Int
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                top = bars.top
                bottom = bars.bottom
            } else {
                top = insets.systemWindowInsetTop
                bottom = insets.systemWindowInsetBottom
            }
            v.setPadding(padH, padTop + top, padH, padBottom + bottom)
            insets
        }
    }

    /** A flexible (weight 1) spacer that expands to push content/buttons apart. */
    private fun flexSpacer(): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f,
        )
    }

    private fun glow(accent: Int): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(withAlpha(accent, 0x2A), cDark, cDark),
        ).apply {
            gradientType = GradientDrawable.RADIAL_GRADIENT
            gradientRadius = dp(340).toFloat()
            setGradientCenter(0.5f, 0.34f)
        }
    }

    /** A circular ring badge holding the state icon, tinted with the accent. */
    private fun iconBadge(accent: Int, iconRes: Int): View {
        val size = dp(96)
        val frame = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(size, size)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(withAlpha(accent, 0x1F))
                setStroke(dp(2), withAlpha(accent, 0x80))
            }
        }
        frame.addView(
            ImageView(this).apply {
                setImageResource(iconRes)
                setColorFilter(accent)
                layoutParams = FrameLayout.LayoutParams(dp(42), dp(42), Gravity.CENTER)
            },
        )
        return frame
    }

    private fun headline(value: String): TextView = TextView(this).apply {
        text = value.uppercase()
        setTextColor(cText)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
        letterSpacing = 0.08f
        gravity = Gravity.CENTER
        typeface = oswald600 ?: Typeface.DEFAULT_BOLD
    }

    private fun bodyText(value: String): TextView = TextView(this).apply {
        text = value
        setTextColor(cText)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        gravity = Gravity.CENTER
        typeface = barlow ?: Typeface.DEFAULT
        setLineSpacing(dp(3).toFloat(), 1f)
    }

    /** Red/amber fill, white label — the one primary action. */
    private fun primaryButton(label: String, accent: Int, onClick: () -> Unit): Button =
        Button(this).apply {
            text = label
            isAllCaps = true
            setTextColor(cWhite)
            letterSpacing = 0.06f
            typeface = oswald600 ?: Typeface.DEFAULT_BOLD
            stateListAnimator = null
            background = GradientDrawable().apply {
                cornerRadius = dp(8).toFloat()
                setColor(accent)
            }
            minimumHeight = dp(54)
            setPadding(dp(24), dp(14), dp(24), dp(14))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            setOnClickListener { onClick() }
        }

    /** De-emphasized secondary action: a plain text link, never a second fill. */
    private fun secondaryLink(label: String, onClick: () -> Unit): Button =
        Button(this).apply {
            text = label
            isAllCaps = true
            setTextColor(cDim)
            typeface = oswald400 ?: Typeface.DEFAULT
            background = null
            stateListAnimator = null
            setOnClickListener { onClick() }
        }

    private fun spacer(height: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, height,
        )
    }

    private fun font(assetPath: String): Typeface? = try {
        Typeface.createFromAsset(assets, assetPath)
    } catch (e: Exception) {
        Log.w(TAG, "Font load failed: $assetPath", e)
        null
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha shl 24)

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics,
    ).toInt()
}
