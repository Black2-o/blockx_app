package com.example.blockx

import com.example.blockx.blocking.AppBlockerService
import com.example.blockx.channel.AppInfoReader
import com.example.blockx.channel.UsageStatsReader

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter to the native blocker over a single [MethodChannel]. This file
 * owns only the channel wiring + permission/settings intents; the read-only data
 * work is delegated to [AppInfoReader] and [UsageStatsReader].
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.blockx.app/blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" ->
                        result.success(AppInfoReader.getInstalledApps(this))

                    // Read-only: today's per-app screen time for the Screen Time
                    // screen. Additive; does not affect any blocking rule.
                    "getUsageStats" ->
                        result.success(UsageStatsReader.getUsageStats(this))

                    // Read-only: per-app screen time for a specific day (its
                    // local-midnight epoch millis). Used by the day navigator.
                    "getUsageForDay" -> result.success(
                        UsageStatsReader.getUsageForDay(
                            this,
                            (call.argument<Number>("dayStartMs"))?.toLong()
                                ?: UsageStatsReader.todayStartMs(),
                        ),
                    )

                    // Read-only: total foreground time per day for [days] days
                    // starting at startMs (a local midnight) — one week's bars.
                    "getUsageHistory" -> result.success(
                        UsageStatsReader.getDailyTotals(
                            this,
                            (call.argument<Number>("startMs"))?.toLong()
                                ?: (UsageStatsReader.todayStartMs() -
                                    6 * UsageStatsReader.DAY_MS),
                            (call.argument<Number>("days"))?.toInt() ?: 7,
                        ),
                    )

                    // Read-only: an app's launcher icon as PNG bytes, for the UI.
                    "getAppIcon" -> result.success(
                        AppInfoReader.getAppIcon(this, call.argument<String>("package") ?: ""),
                    )

                    // Read-only: a single app's display label (cheap; avoids
                    // enumerating every installed app just to name one).
                    "getAppLabel" -> result.success(
                        AppInfoReader.getAppLabel(this, call.argument<String>("package") ?: ""),
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

                    "getDeviceInfo" -> result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "brand" to Build.BRAND,
                            "model" to Build.MODEL,
                            "sdkInt" to Build.VERSION.SDK_INT,
                        ),
                    )

                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(true)
                    }

                    "openAutoStartSettings" -> result.success(openAutoStartSettings())

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Persist the enabled apps' full config where the service can read it.
     * [configsJson] is a JSON object: `{ "<pkg>": {mode, opensPerDay,
     * sessionMinutes}, ... }`.
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

    /** Open this app's system "App info" page (where "Allow restricted settings",
     *  "Other permissions" and autostart toggles live on many OEMs). */
    private fun openAppSettings() {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (_: Exception) {
        }
    }

    /**
     * Best-effort: open the OEM "Autostart / background start" manager so the
     * accessibility service can relaunch itself after being killed. These screens
     * are undocumented and vary by skin, so we try known components in turn and
     * fall back to the app's own settings page. Returns true if a real OEM screen
     * opened, false if we fell back.
     */
    private fun openAutoStartSettings(): Boolean {
        val candidates = listOf(
            // Xiaomi / Redmi / POCO (MIUI/HyperOS)
            ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity",
            ),
            // Oppo / realme / ColorOS
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            ),
            ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.startupapp.StartupAppListActivity",
            ),
            ComponentName(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity",
            ),
            // OnePlus
            ComponentName(
                "com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            ),
            // Vivo / iQOO
            ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            ),
            ComponentName(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            ),
            // Huawei / Honor
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            ),
            ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity",
            ),
        )
        for (cn in candidates) {
            val intent = Intent().apply {
                component = cn
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            if (packageManager.resolveActivity(intent, 0) != null) {
                try {
                    startActivity(intent)
                    return true
                } catch (_: Exception) {
                }
            }
        }
        openAppSettings()
        return false
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
