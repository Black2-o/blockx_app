package com.example.blockx.channel

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import java.util.Calendar

/**
 * Reads real per-app screen time from Android UsageStats. Extracted from
 * [MainActivity] — pure, read-only, no state. Returns plain maps/lists ready to
 * hand straight to the Flutter method channel.
 */
object UsageStatsReader {

    const val DAY_MS = 24L * 60 * 60 * 1000

    /** Local-midnight (today), epoch millis. */
    fun todayStartMs(): Long = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    /**
     * Today's foreground time per app (ms). Requires the granted Usage Access
     * permission. Maps `{packageName, appName, totalTimeMs}`, sorted desc.
     */
    fun getUsageStats(ctx: Context): List<Map<String, Any>> {
        val now = System.currentTimeMillis()
        return aggregateUsage(ctx, todayStartMs(), now)
    }

    /**
     * Per-app foreground time for the single day beginning at [dayStartMs]
     * (local midnight). Window is clamped to "now" so today only counts up to
     * the current moment.
     */
    fun getUsageForDay(ctx: Context, dayStartMs: Long): List<Map<String, Any>> {
        val dayEnd = dayStartMs + DAY_MS
        val end = minOf(dayEnd, System.currentTimeMillis())
        if (end <= dayStartMs) return emptyList()
        return aggregateUsage(ctx, dayStartMs, end)
    }

    /**
     * Total foreground time (ms) for [days] consecutive days beginning at
     * [startMs] (a local midnight), oldest first, as `{dayStartMs, totalMs}`.
     * Each total is the sum of that day's per-app list (same filtering), so the
     * chart and the day view agree. Future days come back as 0; past days only
     * as far back as the phone retains usage events.
     */
    fun getDailyTotals(ctx: Context, startMs: Long, days: Int): List<Map<String, Any>> {
        val n = days.coerceIn(1, 14)
        val out = ArrayList<Map<String, Any>>(n)
        for (i in 0 until n) {
            val dayStart = startMs + i * DAY_MS
            val list = getUsageForDay(ctx, dayStart)
            val total = list.sumOf { (it["totalTimeMs"] as? Long) ?: 0L }
            out.add(mapOf("dayStartMs" to dayStart, "totalMs" to total))
        }
        return out
    }

    /**
     * Per-app foreground time for an arbitrary [start, end] window, computed
     * from [UsageEvents] foreground/background transitions. This is the
     * accurate method (it matches the phone's own Screen Time); the aggregate
     * `queryAndAggregateUsageStats().totalTimeInForeground` over-reports wildly
     * on some OEMs (ColorOS/Realme) and is deliberately NOT used.
     *
     * Only **user-launchable** apps are kept (a CATEGORY_LAUNCHER activity),
     * which drops the things the system Screen Time never shows either — OEM
     * "global search", SystemUI, launchers, and other background/system packages.
     */
    private fun aggregateUsage(ctx: Context, start: Long, end: Long): List<Map<String, Any>> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val events = usm.queryEvents(start, end) ?: return emptyList()
        val lastForeground = HashMap<String, Long>()
        val totals = HashMap<String, Long>()
        val ev = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            when (ev.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND ->
                    lastForeground[pkg] = ev.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val began = lastForeground.remove(pkg)
                    if (began != null && ev.timeStamp > began) {
                        totals[pkg] = (totals[pkg] ?: 0L) + (ev.timeStamp - began)
                    }
                }
            }
        }
        // Apps still in the foreground at the window end.
        for ((pkg, began) in lastForeground) {
            if (end > began) totals[pkg] = (totals[pkg] ?: 0L) + (end - began)
        }

        val pm = ctx.packageManager
        val self = ctx.packageName
        val launchable = launchablePackages(ctx)
        val launchers = launcherPackages(ctx)
        val out = ArrayList<Map<String, Any>>()
        for ((pkg, ms) in totals) {
            if (pkg == self || ms < 1000L) continue // skip self + <1s blips
            // Real, openable apps only — this is what removes "global search"
            // and every other OEM/system phantom, on any phone.
            if (pkg !in launchable) continue
            if (pkg in launchers) continue

            val label = try {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (e: Exception) {
                pkg
            }
            out.add(mapOf("packageName" to pkg, "appName" to label, "totalTimeMs" to ms))
        }
        out.sortByDescending { it["totalTimeMs"] as Long }
        return out.take(25)
    }

    /**
     * Every package that exposes a normal launcher icon — i.e. an app the user
     * can actually open. Keeps Screen Time to real apps.
     */
    private fun launchablePackages(ctx: Context): Set<String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val set = HashSet<String>()
        try {
            for (ri in ctx.packageManager.queryIntentActivities(intent, 0)) {
                ri.activityInfo?.packageName?.let { set.add(it) }
            }
        } catch (_: Exception) {
        }
        return set
    }

    /**
     * Every home-screen / launcher package to hide from Screen Time. Resolves the
     * device's actual HOME activities (covers whatever launcher this phone uses)
     * and adds the common OEM launcher/recents packages ("Quickstep" lives here).
     */
    private fun launcherPackages(ctx: Context): Set<String> {
        val set = HashSet<String>()
        try {
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            for (ri in ctx.packageManager.queryIntentActivities(home, 0)) {
                ri.activityInfo?.packageName?.let { set.add(it) }
            }
        } catch (_: Exception) {
        }
        set.addAll(
            listOf(
                "com.android.systemui",
                "com.google.android.apps.nexuslauncher",
                "com.android.launcher",
                "com.android.launcher2",
                "com.android.launcher3",
                "com.android.quickstep",
                "com.sec.android.app.launcher",   // Samsung One UI
                "com.miui.home",                  // Xiaomi
                "com.mi.android.globallauncher",
                "com.oppo.launcher",              // Oppo
                "com.coloros.launcher",           // Oppo/realme ColorOS
                "com.realme.launcher",
                "com.oneplus.launcher",           // OnePlus
                "com.transsion.XOSLauncher",      // Tecno/Infinix
                "com.huawei.android.launcher",    // Huawei/Honor
                "com.vivo.launcher",              // Vivo
                "com.bbk.launcher2",              // Vivo/iQOO
                "com.microsoft.launcher",
                "com.teslacoilsw.launcher",       // Nova
            ),
        )
        return set
    }
}
