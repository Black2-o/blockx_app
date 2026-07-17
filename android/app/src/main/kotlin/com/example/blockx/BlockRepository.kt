package com.example.blockx

import android.content.Context
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Shared native read/write of the block config + per-app runtime state, used by
 * both [AppBlockerService] (to decide) and [BlockActivity] (to spend an open).
 *
 * Storage (SharedPreferences `block_prefs`):
 *  - `configs_json`  : written by Flutter — `{ "<pkg>": {mode, opensPerDay,
 *                      sessionMinutes}, ... }`, only for enabled apps.
 *  - `state_<pkg>_*` : written by native — the day's opens used + the current
 *                      session end time. Resets when the calendar day changes.
 */
object BlockRepository {

    private const val PREFS = "block_prefs"

    data class Config(
        val mode: String,
        val opensPerDay: Int,
        val sessionMinutes: Int,
    )

    /** What should happen for a given foreground package right now. */
    enum class Decision {
        /** Not in the block list (or disabled) — leave it alone. */
        NONE,

        /** A time-limited session is active — allow the app, show the widget. */
        ALLOW_SESSION,

        /** Time-limited, opens remaining — show the "is this really needed?" screen. */
        INTERSTITIAL,

        /** Direct-blocked, or time-limited with the daily quota used up. */
        BLOCK,
    }

    private fun prefs(ctx: Context) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun today(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    fun configFor(ctx: Context, pkg: String): Config? {
        val json = prefs(ctx).getString("configs_json", "{}") ?: "{}"
        return try {
            val obj = JSONObject(json)
            if (!obj.has(pkg)) return null
            val c = obj.getJSONObject(pkg)
            Config(
                mode = c.optString("mode", "direct"),
                opensPerDay = c.optInt("opensPerDay", 5),
                sessionMinutes = c.optInt("sessionMinutes", 5),
            )
        } catch (_: Exception) {
            null
        }
    }

    /** Opens used today (0 if the stored day isn't today — i.e. a fresh day). */
    fun opensUsedToday(ctx: Context, pkg: String): Int {
        val p = prefs(ctx)
        if (p.getString("state_${pkg}_date", "") != today()) return 0
        return p.getInt("state_${pkg}_opens", 0)
    }

    fun opensLeftToday(ctx: Context, pkg: String): Int {
        val cfg = configFor(ctx, pkg) ?: return 0
        return (cfg.opensPerDay - opensUsedToday(ctx, pkg)).coerceAtLeast(0)
    }

    fun sessionEndAt(ctx: Context, pkg: String): Long =
        prefs(ctx).getLong("state_${pkg}_sessionEnd", 0L)

    fun sessionMillisLeft(ctx: Context, pkg: String): Long =
        (sessionEndAt(ctx, pkg) - System.currentTimeMillis()).coerceAtLeast(0L)

    /** Spend one open and start a session of the app's configured length. */
    fun startSession(ctx: Context, pkg: String) {
        val cfg = configFor(ctx, pkg) ?: return
        val used = opensUsedToday(ctx, pkg) // already daily-reset aware
        prefs(ctx).edit()
            .putString("state_${pkg}_date", today())
            .putInt("state_${pkg}_opens", used + 1)
            .putLong(
                "state_${pkg}_sessionEnd",
                System.currentTimeMillis() + cfg.sessionMinutes * 60_000L,
            )
            .apply()
    }

    /** End the current session immediately (the "End now" button). */
    fun endSession(ctx: Context, pkg: String) {
        prefs(ctx).edit().putLong("state_${pkg}_sessionEnd", 0L).apply()
    }

    fun decide(ctx: Context, pkg: String): Decision {
        val cfg = configFor(ctx, pkg) ?: return Decision.NONE
        if (cfg.mode == "direct") return Decision.BLOCK
        if (sessionEndAt(ctx, pkg) > System.currentTimeMillis()) {
            return Decision.ALLOW_SESSION
        }
        return if (opensUsedToday(ctx, pkg) >= cfg.opensPerDay) {
            Decision.BLOCK
        } else {
            Decision.INTERSTITIAL
        }
    }
}
