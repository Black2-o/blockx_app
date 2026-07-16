package com.example.block

import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
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

    private val channelName = "com.block.app/blocker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())

                    "setConfigs" -> {
                        val configsJson = call.argument<String>("configsJson") ?: "{}"
                        saveConfigs(configsJson)
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
