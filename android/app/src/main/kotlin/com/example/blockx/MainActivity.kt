package com.example.blockx

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import java.io.ByteArrayOutputStream
import java.util.Calendar
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter to the native blocker over a single [MethodChannel].
 *
 * Methods:
 *  - getInstalledApps          -> List<Map> {appName, packageName} of launchable apps
 *  - setBlockedPackages {list} -> share the currently-ON packages with the service
 *  - isAccessibilityEnabled    -> is our AccessibilityService turned on?
 *  - openAccessibilitySettings -> open the system Accessibility screen
 *  - canDrawOverlays           -> is "draw over other apps" granted?
 *  - openOverlaySettings       -> open the system overlay-permission screen
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.blockx.app/blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())

                    // Read-only: today's per-app screen time for the Screen Time
                    // screen. Additive; does not affect any blocking rule.
                    "getUsageStats" -> result.success(getUsageStats())

                    // Read-only: an app's launcher icon as PNG bytes, for the UI.
                    "getAppIcon" -> result.success(
                        getAppIcon(call.argument<String>("package") ?: ""),
                    )

                    // Read-only: a single app's display label (cheap; avoids
                    // enumerating every installed app just to name one).
                    "getAppLabel" -> result.success(
                        getAppLabel(call.argument<String>("package") ?: ""),
                    )

                    "setConfigs" -> {
                        val configsJson = call.argument<String>("configsJson") ?: "{}"
                        saveConfigs(configsJson)
                        result.success(true)
                    }

                    "setBlockedSites" -> {
                        val sitesJson = call.argument<String>("sitesJson") ?: "[]"
                        getSharedPreferences("block_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .putString("blocked_sites_json", sitesJson)
                            .apply()
                        result.success(true)
                    }

                    "setFeatureBlocks" -> {
                        val featuresJson = call.argument<String>("featuresJson") ?: "{}"
                        getSharedPreferences("block_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .putString("feature_blocks_json", featuresJson)
                            .apply()
                        result.success(true)
                    }

                    // Mirror the UI-only block streaks to native (id -> streak
                    // start epoch-millis) so the block screen can show them.
                    "setStreaks" -> {
                        val streaksJson = call.argument<String>("streaksJson") ?: "{}"
                        getSharedPreferences("block_prefs", Context.MODE_PRIVATE)
                            .edit()
                            .putString("streaks_json", streaksJson)
                            .apply()
                        result.success(true)
                    }

                    "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    }

                    "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))

                    "openOverlaySettings" -> {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    }

                    "hasUsageAccess" -> result.success(hasUsageAccess())

                    "openUsageAccessSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(true)
                    }

                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())

                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /** All launchable apps on the device, as maps for the Flutter side. */
    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val launchable = Intent(Intent.ACTION_MAIN, null)
            .addCategory(Intent.CATEGORY_LAUNCHER)

        val resolved = pm.queryIntentActivities(launchable, 0)
        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, String>>()

        for (info in resolved) {
            val pkg = info.activityInfo.packageName
            if (pkg == packageName) continue // don't list ourselves
            if (!seen.add(pkg)) continue
            val label = info.loadLabel(pm)?.toString() ?: pkg
            apps.add(mapOf("appName" to label, "packageName" to pkg))
        }
        return apps
    }

    /**
     * Today's foreground time per app (ms). Read-only; requires the granted
     * Usage Access permission. Returns maps `{packageName, appName, totalTimeMs}`
     * sorted by time desc. Additive — touches no blocking config or state.
     *
     * Computed from [UsageEvents] (foreground/background transitions) rather than
     * `queryUsageStats().totalTimeInForeground`, which returns overlapping daily
     * buckets and hugely over-counts when summed.
     */
    private fun getUsageStats(): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val end = System.currentTimeMillis()
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

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
        // Apps still in the foreground at query time.
        for ((pkg, began) in lastForeground) {
            if (end > began) totals[pkg] = (totals[pkg] ?: 0L) + (end - began)
        }

        val pm = packageManager
        val launchers = launcherPackages()
        val out = ArrayList<Map<String, Any>>()
        for ((pkg, ms) in totals) {
            if (pkg == packageName || ms < 1000L) continue // skip self + <1s blips
            // Skip home screens / launchers (the "Quickstep" entry on Pixel/AOSP
            // and every OEM launcher) — that's not an app the user "used".
            if (pkg in launchers) continue
            val lower = pkg.lowercase()
            if (lower.contains("launcher") || lower.contains("quickstep")) continue
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
     * Every home-screen / launcher package to hide from Screen Time. Resolves the
     * device's actual HOME activities (covers whatever launcher this phone uses)
     * and adds the common OEM launcher/recents packages ("Quickstep" lives in
     * these). The substring filter in [getUsageStats] catches any others.
     */
    private fun launcherPackages(): Set<String> {
        val set = HashSet<String>()
        try {
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            for (ri in packageManager.queryIntentActivities(home, 0)) {
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

    /** An app's display label, or the package name if it can't be resolved. */
    private fun getAppLabel(pkg: String): String {
        if (pkg.isEmpty()) return pkg
        return try {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(pkg, 0),
            ).toString()
        } catch (e: Exception) {
            pkg
        }
    }

    /** An app's launcher icon as PNG bytes (~96px), or null. Read-only. */
    private fun getAppIcon(pkg: String): ByteArray? {
        if (pkg.isEmpty()) return null
        return try {
            val drawable = packageManager.getApplicationIcon(pkg)
            val bmp = drawableToBitmap(drawable)
            ByteArrayOutputStream().use { out ->
                bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
                out.toByteArray()
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) return drawable.bitmap
        val size = (96 * resources.displayMetrics.density).toInt().coerceAtLeast(96)
        val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else size
        val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else size
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bmp
    }

    /**
     * Persist the enabled apps' full config where the service can read it.
     * [configsJson] is a JSON object: `{ "<pkg>": {mode, opensPerDay,
     * sessionMinutes}, ... }`. When an app is removed from the list (or turned
     * off), it disappears from this blob; we clear any leftover runtime state for
     * packages no longer present so a re-added app starts fresh.
     */
    private fun saveConfigs(configsJson: String) {
        val prefs = getSharedPreferences("block_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("configs_json", configsJson).apply()
    }

    /** True if our AccessibilityService is enabled in system settings. */
    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(this, AppBlockerService::class.java)
            .flattenToString()
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    /** True if this app is already exempt from battery optimization. */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Ask the system to exempt us from battery optimization. Prefers the direct
     * "allow?" dialog (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS); if the OEM
     * blocks that, falls back to the full battery-optimization list screen.
     */
    private fun openBatteryOptimizationSettings() {
        val direct = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(direct)
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } catch (_: Exception) {
            }
        }
    }

    /** True if the user granted "Usage access" to this app. */
    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
}
