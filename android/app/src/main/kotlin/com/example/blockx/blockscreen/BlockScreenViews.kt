package com.example.blockx.blockscreen

import com.example.blockx.R
import com.example.blockx.common.BlockPalette

import android.content.Context
import android.graphics.Typeface
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.os.Build
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

/**
 * All the no-XML styled view builders for [BlockActivity] (BlockX visual
 * language — see details/ui-redesign/03-SCREENS-SPEC.md). Extracted so the
 * Activity keeps only its mode/countdown/session logic. Pure view factories:
 * no behaviour, colours come from [BlockPalette].
 */
class BlockScreenViews(private val ctx: Context) {

    private companion object {
        const val TAG = "BlockX"
    }

    // Bundled fonts (loaded from Flutter assets; null-safe fallback).
    private val oswald600 by lazy { font("flutter_assets/assets/fonts/Oswald-SemiBold.ttf") }
    private val oswald400 by lazy { font("flutter_assets/assets/fonts/Oswald-Regular.ttf") }
    private val barlow by lazy { font("flutter_assets/assets/fonts/BarlowCondensed-Regular.ttf") }

    /** Root: full-height column on the dark background with a soft radial glow.
     *  Content is centered by flex spacers; the action button sits at the bottom. */
    @Suppress("DEPRECATION")
    fun container(accent: Int): LinearLayout = LinearLayout(ctx).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        background = glow(accent)
        val padH = dp(28)
        val padTop = dp(28)
        val padBottom = dp(24)
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
    fun flexSpacer(): View = View(ctx).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f,
        )
    }

    private fun glow(accent: Int): GradientDrawable {
        return GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(withAlpha(accent, 0x2A), BlockPalette.dark, BlockPalette.dark),
        ).apply {
            gradientType = GradientDrawable.RADIAL_GRADIENT
            gradientRadius = dp(340).toFloat()
            setGradientCenter(0.5f, 0.34f)
        }
    }

    /** A circular ring badge holding the state icon, tinted with the accent. */
    fun iconBadge(accent: Int, iconRes: Int): View {
        val size = dp(96)
        val frame = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(size, size)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(withAlpha(accent, 0x1F))
                setStroke(dp(2), withAlpha(accent, 0x80))
            }
        }
        frame.addView(
            ImageView(ctx).apply {
                setImageResource(iconRes)
                setColorFilter(accent)
                layoutParams = FrameLayout.LayoutParams(dp(42), dp(42), Gravity.CENTER)
            },
        )
        return frame
    }

    /**
     * A ring badge holding the blocked app's real launcher icon (features fall
     * back to the feature glyph), with a small accent hourglass chip to mark the
     * timed state. Used by the interstitial only.
     */
    fun appBadge(pkg: String?, accent: Int, isFeature: Boolean): View {
        val size = dp(100)
        val frame = FrameLayout(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(size, size)
        }
        // Tinted ring.
        frame.addView(
            View(ctx).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(withAlpha(accent, 0x1F))
                    setStroke(dp(2), withAlpha(accent, 0x80))
                }
                layoutParams = FrameLayout.LayoutParams(size, size)
            },
        )
        // Main icon: real app icon, or a tinted glyph fallback.
        val appDrawable = appIcon(pkg, isFeature)
        frame.addView(
            ImageView(ctx).apply {
                val isz = dp(54)
                if (appDrawable != null) {
                    setImageDrawable(appDrawable)
                } else {
                    setImageResource(
                        if (isFeature) R.drawable.ic_block_feature
                        else R.drawable.ic_block_hourglass,
                    )
                    setColorFilter(accent)
                }
                layoutParams = FrameLayout.LayoutParams(isz, isz, Gravity.CENTER)
            },
        )
        // Small hourglass state chip, bottom-right.
        frame.addView(
            ImageView(ctx).apply {
                setImageResource(R.drawable.ic_block_hourglass)
                setColorFilter(BlockPalette.white)
                setPadding(dp(6), dp(6), dp(6), dp(6))
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(accent)
                    setStroke(dp(2), BlockPalette.dark)
                }
                layoutParams = FrameLayout.LayoutParams(dp(30), dp(30),
                    Gravity.BOTTOM or Gravity.END)
            },
        )
        return frame
    }

    /** The blocked app's real launcher icon, or null (features / not found). */
    private fun appIcon(pkg: String?, isFeature: Boolean): Drawable? {
        if (pkg == null || isFeature) return null
        return try {
            ctx.packageManager.getApplicationIcon(pkg)
        } catch (_: Exception) {
            null
        }
    }

    fun headline(value: String): TextView = TextView(ctx).apply {
        text = value.uppercase()
        setTextColor(BlockPalette.text)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
        letterSpacing = 0.08f
        gravity = Gravity.CENTER
        typeface = oswald600 ?: Typeface.DEFAULT_BOLD
    }

    fun bodyText(value: String): TextView = TextView(ctx).apply {
        text = value
        setTextColor(BlockPalette.text)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        gravity = Gravity.CENTER
        typeface = barlow ?: Typeface.DEFAULT
        setLineSpacing(dp(3).toFloat(), 1f)
    }

    /** The app/feature name, in the accent and bold, under the headline. */
    fun appNameLine(name: String, accent: Int): TextView = TextView(ctx).apply {
        text = name
        setTextColor(accent)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
        gravity = Gravity.CENTER
        letterSpacing = 0.03f
        typeface = oswald600 ?: Typeface.DEFAULT_BOLD
    }

    /** Small dim uppercase overline, e.g. "OPENS LEFT TODAY". */
    fun overlineLabel(value: String): TextView = TextView(ctx).apply {
        text = value.uppercase()
        setTextColor(BlockPalette.textDim)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
        letterSpacing = 0.16f
        gravity = Gravity.CENTER
        typeface = oswald400 ?: Typeface.DEFAULT
    }

    /** "3 of 5 left" — the remaining count in the accent, the rest in body text. */
    fun opensCountLine(left: Int, total: Int, accent: Int): View {
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        row.addView(
            TextView(ctx).apply {
                text = "$left"
                setTextColor(accent)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                typeface = oswald600 ?: Typeface.DEFAULT_BOLD
            },
        )
        row.addView(
            TextView(ctx).apply {
                text = "  of $total left"
                setTextColor(BlockPalette.text)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                typeface = barlow ?: Typeface.DEFAULT
            },
        )
        return row
    }

    /** A "🔥 N days blocked" streak line, in the accent. */
    fun streakLine(days: Int, accent: Int): TextView {
        val noun = if (days == 1) "day" else "days"
        return TextView(ctx).apply {
            text = "🔥  $days $noun blocked"
            setTextColor(accent)
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
    fun opensDots(left: Int, total: Int, accent: Int): View {
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        val size = dp(13)
        val gap = dp(6)
        for (i in 0 until total) {
            val filled = i < left
            val dot = View(ctx).apply {
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    if (filled) {
                        setColor(accent)
                    } else {
                        setColor(BlockPalette.transparent)
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

    /** Red/amber fill, white label — the one primary action. */
    fun primaryButton(label: String, accent: Int, onClick: () -> Unit): Button =
        Button(ctx).apply {
            text = label
            isAllCaps = true
            setTextColor(BlockPalette.white)
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
    fun secondaryLink(label: String, onClick: () -> Unit): Button =
        Button(ctx).apply {
            text = label
            isAllCaps = true
            setTextColor(BlockPalette.textDim)
            typeface = oswald400 ?: Typeface.DEFAULT
            background = null
            stateListAnimator = null
            setOnClickListener { onClick() }
        }

    fun spacer(height: Int): View = View(ctx).apply {
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, height,
        )
    }

    private fun font(assetPath: String): Typeface? = try {
        Typeface.createFromAsset(ctx.assets, assetPath)
    } catch (e: Exception) {
        Log.w(TAG, "Font load failed: $assetPath", e)
        null
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha shl 24)

    fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), ctx.resources.displayMetrics,
    ).toInt()
}
