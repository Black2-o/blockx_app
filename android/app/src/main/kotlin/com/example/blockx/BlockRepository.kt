package com.example.blockx

import android.content.Context
import org.json.JSONArray
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

    // ---- Website blocking ----

    /**
     * All blocked website hosts: the user's in-app list (`blocked_sites_json`)
     * PLUS the always-on built-ins from [BuiltInBlocklist]. Everything is
     * reduced to a bare host and de-duplicated. The built-ins are read straight
     * from code here, so they apply even if the user never opens the app.
     */
    fun blockedSites(ctx: Context): List<String> {
        val json = prefs(ctx).getString("blocked_sites_json", "[]") ?: "[]"
        val user = try {
            val arr = JSONArray(json)
            (0 until arr.length()).map { arr.optString(it, "") }
        } catch (_: Exception) {
            emptyList()
        }
        return (user + BuiltInBlocklist.domains)
            .map { normalizeHost(it) }
            .filter { it.isNotEmpty() }
            .distinct()
    }

    /** Reduce a URL/host to a bare host: lowercase, no scheme/`www.`/path. */
    fun normalizeHost(input: String): String {
        var s = input.trim().lowercase()
        if (s.isEmpty()) return s
        s = s.substringAfter("://")
        if (s.startsWith("www.")) s = s.substring(4)
        s = s.substringBefore("/").substringBefore("?").substringBefore("#")
        return s.trim()
    }

    // ---- In-app feature blocking (Shorts / Reels) ----

    /**
     * The config for a sub-feature key (e.g. "yt_shorts"), or null if that
     * feature is off. Same shape as an app [Config] (`mode` = direct|timed +
     * opens/minutes), read from `feature_blocks_json` (only enabled features are
     * mirrored there by Flutter, so "present" == "on").
     */
    fun featureConfigFor(ctx: Context, key: String): Config? {
        val json = prefs(ctx).getString("feature_blocks_json", "{}") ?: "{}"
        return try {
            val obj = JSONObject(json)
            if (!obj.has(key)) return null
            val c = obj.getJSONObject(key)
            Config(
                mode = c.optString("mode", "direct"),
                opensPerDay = c.optInt("opensPerDay", 5),
                sessionMinutes = c.optInt("sessionMinutes", 5),
            )
        } catch (_: Exception) {
            null
        }
    }

    /** Config for an id that may be either an app package OR a feature key. */
    private fun anyConfig(ctx: Context, id: String): Config? =
        configFor(ctx, id) ?: featureConfigFor(ctx, id)

    /**
     * Whether the given browser address-bar text points at a blocked site.
     * [urlText] is whatever the URL bar shows (e.g. "youtube.com",
     * "https://m.youtube.com/watch", "🔒 example.com/path"). Matches a blocked
     * host as a whole host token so "youtube.com" blocks "m.youtube.com" and
     * "youtube.com/feed" but NOT "notyoutube.com" or "youtube.company".
     */
    fun isBlockedHost(ctx: Context, urlText: String?): Boolean {
        val text = urlText?.lowercase() ?: return false
        if (text.isBlank()) return false
        return blockedSites(ctx).any { site -> hostMatches(text, site) }
    }

    private fun hostMatches(text: String, site: String): Boolean {
        if (site.isEmpty()) return false
        var idx = text.indexOf(site)
        while (idx >= 0) {
            val before = if (idx == 0) ' ' else text[idx - 1]
            val afterIdx = idx + site.length
            val after = if (afterIdx >= text.length) ' ' else text[afterIdx]
            // Left edge: '.' allowed (subdomains), but not a letter/digit/'-'
            // (so "notyoutube.com" doesn't match). Right edge: not a
            // letter/digit/'-'/'.' (so "youtube.com" doesn't match "youtube.company").
            val beforeOk = !before.isLetterOrDigit() && before != '-'
            val afterOk = !after.isLetterOrDigit() && after != '-' && after != '.'
            if (beforeOk && afterOk) return true
            idx = text.indexOf(site, idx + 1)
        }
        return false
    }

    /** Opens used today (0 if the stored day isn't today — i.e. a fresh day). */
    fun opensUsedToday(ctx: Context, pkg: String): Int {
        val p = prefs(ctx)
        if (p.getString("state_${pkg}_date", "") != today()) return 0
        return p.getInt("state_${pkg}_opens", 0)
    }

    fun opensLeftToday(ctx: Context, pkg: String): Int {
        val cfg = anyConfig(ctx, pkg) ?: return 0
        return (cfg.opensPerDay - opensUsedToday(ctx, pkg)).coerceAtLeast(0)
    }

    fun sessionEndAt(ctx: Context, pkg: String): Long =
        prefs(ctx).getLong("state_${pkg}_sessionEnd", 0L)

    fun sessionMillisLeft(ctx: Context, pkg: String): Long =
        (sessionEndAt(ctx, pkg) - System.currentTimeMillis()).coerceAtLeast(0L)

    /** Spend one open and start a session of the app's/feature's configured length. */
    fun startSession(ctx: Context, pkg: String) {
        val cfg = anyConfig(ctx, pkg) ?: return
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
