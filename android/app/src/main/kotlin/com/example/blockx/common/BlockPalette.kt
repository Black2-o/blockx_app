package com.example.blockx.common

/**
 * The single source of truth for every colour used in native views (the block
 * screen and the floating countdown widget). This is the Kotlin mirror of
 * lib/theme/app_colors.dart — keep the two in sync. Never write a raw colour
 * literal in a view file; reference a value here.
 *
 * (These are `val`, not `const`, because `0xFF…….toInt()` isn't a compile-time
 * constant in Kotlin. The object is a singleton, so each is computed once.)
 */
object BlockPalette {
    /** Outermost background. */
    val dark = 0xFF080808.toInt()
    /** Primary surface: cards / panels. */
    val dark2 = 0xFF111111.toInt()
    /** Input / recessed fills. */
    val dark3 = 0xFF161010.toInt()

    /** Hard-block accent. */
    val red = 0xFFE8000D.toInt()
    /** Bright flame red. */
    val redBright = 0xFFFF3521.toInt()
    /** Friction / timed accent. */
    val amber = 0xFFFFB020.toInt()
    /** "Allowed" accent. */
    val emerald = 0xFF34D399.toInt()

    /** Default text. */
    val text = 0xFFF0E0E0.toInt()
    /** Secondary / dim text. */
    val textDim = 0x80F0C8C8.toInt()
    /** Text on a solid red/amber fill. */
    val white = 0xFFFFFFFF.toInt()

    /** Hairline border. */
    val border = 0x14FFFFFF.toInt()

    /** Floating overlay pill background + hairline. */
    val overlayPanel = 0xF0111111.toInt()
    val overlayStroke = 0x22FFFFFF.toInt()

    /** Fully transparent. */
    val transparent = 0x00000000
}
