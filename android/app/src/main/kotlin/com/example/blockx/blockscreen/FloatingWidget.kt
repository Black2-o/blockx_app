package com.example.blockx.blockscreen

import com.example.blockx.R
import com.example.blockx.blocking.BlockRepository
import com.example.blockx.common.BlockCatalog
import com.example.blockx.common.BlockPalette

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The small floating countdown widget shown over an app during an allowed timed
 * session: a draggable logo handle that expands into a pill — [app icon] [time
 * left] [Relock]. Extracted from [AppBlockerService] so the service file stays
 * focused on detection/decisions.
 *
 * It owns all its own view state and window management; it calls back to the
 * service only for the Relock action ([onRelock]) and uses the service's
 * [handler] for the auto-collapse timer. Behaviour is unchanged from when this
 * lived inside the service.
 */
class FloatingWidget(
    private val ctx: Context,
    private val handler: Handler,
    private val onRelock: (pkg: String) -> Unit,
) {

    private var floatingView: View? = null
    private var floatingParams: WindowManager.LayoutParams? = null
    private var floatingIcon: View? = null
    private var floatingPanel: View? = null
    private var floatingPackage: String? = null
    private var floatingExpanded = false
    private var floatingTimeText: TextView? = null

    /** The package/feature-key the widget is currently showing for, if any. */
    val currentPackage: String? get() = floatingPackage

    // Auto-collapse the expanded pill back to just the logo after a short while.
    private var collapseRunnable: Runnable? = null
    private val autoCollapseMs = 4000L

    // Remembered position between rebuilds: which side edge it's parked on and
    // its vertical offset. Defaults to the LEFT edge; the user can drag it to the
    // right and that choice is then remembered. -1 y means "not placed yet".
    private var floatingIsLeftEdge = true
    private var floatingY = -1

    // Drag state for the touch handler (tap = expand, drag = move + snap).
    private var dragStartRawX = 0f
    private var dragStartRawY = 0f
    private var dragStartX = 0
    private var dragStartY = 0
    private var dragMoved = false

    fun show(pkg: String) {
        if (floatingView != null && floatingPackage == pkg) {
            refresh()
            return
        }
        hide()

        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return
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
        val row = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        // BlockX palette — single source of truth: BlockPalette.kt.
        val cRed = BlockPalette.red
        val cText = BlockPalette.text

        // Collapsed handle: BlockX's own logo, and ONLY the logo — the adaptive
        // icon's foreground layer, which is transparent (no white background
        // square). Parked half-tucked against the screen edge (see anchorToEdge).
        val icon = ImageView(ctx).apply {
            setImageResource(R.drawable.ic_launcher_foreground)
            scaleType = ImageView.ScaleType.FIT_CENTER
            val size = dp(42)
            layoutParams = LinearLayout.LayoutParams(size, size)
        }

        // Expanded pill: a single rounded bar — [app icon] [time left] [Relock].
        val panel = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            visibility = View.GONE
            background = GradientDrawable().apply {
                cornerRadius = dp(15).toFloat()
                setColor(BlockPalette.overlayPanel)
                setStroke(dp(1), BlockPalette.overlayStroke)
            }
            // A bit more breathing room around the whole row (icon · time · button).
            setPadding(dp(11), dp(7), dp(9), dp(7))
        }

        // The blocked app's / feature's own icon, small. Tapping it collapses
        // the pill back to the logo handle.
        val appIcon = ImageView(ctx).apply {
            setImageDrawable(
                try {
                    ctx.packageManager.getApplicationIcon(iconPackageFor(pkg))
                } catch (_: Exception) {
                    null
                },
            )
            val size = dp(24)
            layoutParams = LinearLayout.LayoutParams(size, size)
            setOnClickListener { toggleFloatingPanel() }
        }

        val time = TextView(ctx).apply {
            setTextColor(cText)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setTypeface(Typeface.DEFAULT_BOLD)
            // Centre the label and reserve enough room for the widest form
            // ("1m 59s") so the pill doesn't jump as the text grows/shrinks.
            gravity = Gravity.CENTER
            minWidth = dp(50)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply {
                marginStart = dp(8)
                marginEnd = dp(9)
            }
        }

        val relock = Button(ctx).apply {
            text = "Relock"
            isAllCaps = true
            setTextColor(BlockPalette.white)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTypeface(Typeface.DEFAULT_BOLD)
            stateListAnimator = null
            minWidth = 0
            minHeight = 0
            minimumWidth = 0
            minimumHeight = 0
            // Kill the extra vertical space Button/TextView reserve for font
            // metrics + line spacing, so the pill hugs the text top-and-bottom.
            includeFontPadding = false
            setLineSpacing(0f, 1f)
            setPadding(dp(10), dp(4), dp(10), dp(4))
            background = GradientDrawable().apply {
                cornerRadius = dp(3).toFloat()
                setColor(cRed)
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
            setOnClickListener { onRelock(pkg) }
        }
        panel.addView(appIcon)
        panel.addView(time)
        panel.addView(relock)

        floatingTimeText = time
        floatingIcon = icon
        floatingPanel = panel

        // Fixed child order: panel then icon (we never mutate the live overlay's
        // hierarchy — that caused a null-child insets crash). Expanding hides the
        // icon and shows the pill; anchorToEdge() re-pins the whole row.
        row.addView(panel)
        row.addView(icon)
        return row
    }

    /** The package whose launcher icon represents a session (feature key -> host app). */
    private fun iconPackageFor(id: String): String =
        BlockCatalog.featureApps.entries.firstOrNull { it.value == id }?.key ?: id

    /** Drag to move, release to snap to the nearest side edge; tap = expand. */
    @android.annotation.SuppressLint("ClickableViewAccessibility")
    private fun attachDragHandler() {
        val icon = floatingIcon ?: return
        val slop = ViewConfiguration.get(ctx).scaledTouchSlop
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

    /**
     * Pin x against the parked edge, using the widget's current width. Expanded,
     * the pill sits flush and fully on-screen; collapsed, the logo handle is
     * tucked ~20% behind the edge so it sits out of the way.
     */
    private fun anchorToEdge() {
        val view = floatingView ?: return
        val params = floatingParams ?: return
        val w = view.width
        if (floatingExpanded) {
            params.x = if (floatingIsLeftEdge) 0 else (screenWidthPx() - w).coerceAtLeast(0)
        } else {
            val tuck = (w * 0.2f).toInt()
            params.x = if (floatingIsLeftEdge) -tuck else (screenWidthPx() - w + tuck)
        }
    }

    private fun updateLayout(view: View, params: WindowManager.LayoutParams) {
        try {
            (ctx.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)
                ?.updateViewLayout(view, params)
        } catch (_: Exception) {
        }
    }

    private fun screenWidthPx(): Int = ctx.resources.displayMetrics.widthPixels

    private fun screenHeightPx(): Int = ctx.resources.displayMetrics.heightPixels

    private fun toggleFloatingPanel() {
        floatingExpanded = !floatingExpanded
        floatingPanel?.visibility = if (floatingExpanded) View.VISIBLE else View.GONE
        // Expanded shows only the pill; collapsed shows only the logo handle.
        floatingIcon?.visibility = if (floatingExpanded) View.GONE else View.VISIBLE
        refresh()
        // While expanded, arm a timer to auto-close it; collapsing cancels it.
        if (floatingExpanded) scheduleAutoCollapse() else cancelAutoCollapse()
        // The panel changes the widget's width; re-pin it to the parked edge
        // once the new size is measured so it never runs off-screen.
        val view = floatingView ?: return
        view.post {
            anchorToEdge()
            floatingParams?.let { updateLayout(view, it) }
        }
    }

    /** Auto-close the expanded pill after [autoCollapseMs], back to just the logo. */
    private fun scheduleAutoCollapse() {
        cancelAutoCollapse()
        val r = Runnable { if (floatingExpanded) toggleFloatingPanel() }
        collapseRunnable = r
        handler.postDelayed(r, autoCollapseMs)
    }

    private fun cancelAutoCollapse() {
        collapseRunnable?.let { handler.removeCallbacks(it) }
        collapseRunnable = null
    }

    fun refresh() {
        val pkg = floatingPackage ?: return
        if (!floatingExpanded) return
        val msLeft = BlockRepository.sessionMillisLeft(ctx, pkg)
        // Seconds remaining, rounded up so it never reads 0 while time is left.
        val totalSec = if (msLeft <= 0) 0 else ((msLeft + 999L) / 1000L).toInt()
        floatingTimeText?.text = when {
            totalSec <= 0  -> "0s"
            // Final stretch (under 2 min): count the seconds down too — "1m 59s".
            totalSec < 120 -> "${totalSec / 60}m ${totalSec % 60}s"
            // Otherwise just whole minutes, rounded up — "3m", "12m".
            else           -> "${(totalSec + 59) / 60}m"
        }
    }

    fun hide() {
        cancelAutoCollapse()
        val view = floatingView ?: return
        try {
            (ctx.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)?.removeView(view)
        } catch (_: Exception) {
        }
        floatingView = null
        floatingParams = null
        floatingIcon = null
        floatingPanel = null
        floatingPackage = null
        floatingExpanded = false
        floatingTimeText = null
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), ctx.resources.displayMetrics,
    ).toInt()
}
