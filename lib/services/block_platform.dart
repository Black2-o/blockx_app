import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/app_info.dart';
import '../models/app_usage.dart';
import '../models/block_config.dart';

/// Thin Dart wrapper over the native Kotlin blocker (`MainActivity` +
/// `AppBlockerService`) via a single [MethodChannel].
///
/// Blocking is done natively with an Accessibility Service + a full-screen
/// overlay — no VPN. This class is the only place Dart talks to it.
class BlockPlatform {
  BlockPlatform._();

  static const MethodChannel _channel = MethodChannel('com.blockx.app/blocker');

  /// Every launchable app installed on the device.
  static Future<List<AppInfo>> getInstalledApps() async {
    final List<dynamic> result =
        await _channel.invokeMethod('getInstalledApps') as List<dynamic>;
    return result
        .map((e) => AppInfo.fromMap(e as Map<dynamic, dynamic>))
        .toList()
      ..sort((a, b) =>
          a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
  }

  /// An app's launcher icon as PNG bytes (read-only), or null if unavailable.
  static Future<Uint8List?> getAppIcon(String packageName) async {
    final result = await _channel
        .invokeMethod('getAppIcon', {'package': packageName});
    return result as Uint8List?;
  }

  /// An app's display label (read-only). Falls back to the package name.
  static Future<String> getAppLabel(String packageName) async {
    final result =
        await _channel.invokeMethod('getAppLabel', {'package': packageName});
    return (result as String?) ?? packageName;
  }

  /// Today's per-app foreground time (read-only, from Android UsageStats).
  /// Requires the already-granted Usage Access permission. Additive — does not
  /// touch any blocking config.
  static Future<List<AppUsage>> getUsageStats() async {
    final List<dynamic> result =
        await _channel.invokeMethod('getUsageStats') as List<dynamic>;
    return result
        .map((e) => AppUsage.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  /// Shares the full config of the currently-ON apps with the native service,
  /// as a JSON object: `{ "<package>": {mode, opensPerDay, sessionMinutes}, ... }`.
  /// Only enabled apps should be passed. Native uses this to decide, per app,
  /// whether to block outright or run the time-limited flow.
  static Future<void> setConfigs(Map<String, BlockConfig> configs) async {
    final payload = <String, dynamic>{
      for (final e in configs.entries) e.key: e.value.toMap(),
    };
    await _channel.invokeMethod('setConfigs', {'configsJson': jsonEncode(payload)});
  }

  /// Shares the list of blocked website domains with the native service as a
  /// JSON array: `["youtube.com", "instagram.com", ...]`. The service reads a
  /// browser's address bar and bounces off any URL matching one of these.
  static Future<void> setBlockedSites(List<String> sites) async {
    await _channel.invokeMethod('setBlockedSites', {'sitesJson': jsonEncode(sites)});
  }

  /// Shares the enabled in-app sub-feature configs (Shorts/Reels) with the
  /// native service as a JSON object: `{ "yt_shorts": {mode, opensPerDay,
  /// sessionMinutes}, ... }`. Only enabled features should be passed. Native
  /// treats "present" as "on" and reads the config (direct vs timed).
  static Future<void> setFeatureBlocks(Map<String, BlockConfig> configs) async {
    final payload = <String, dynamic>{
      for (final e in configs.entries) e.key: e.value.toMap(),
    };
    await _channel
        .invokeMethod('setFeatureBlocks', {'featuresJson': jsonEncode(payload)});
  }

  /// Mirrors the UI-only block streaks to native (`id -> streak start epoch
  /// millis`) so the native block screen can show a "N-day streak". Additive —
  /// does not affect any blocking decision.
  static Future<void> setStreaks(Map<String, int> startsMillis) async {
    await _channel
        .invokeMethod('setStreaks', {'streaksJson': jsonEncode(startsMillis)});
  }

  /// Whether our Accessibility Service is enabled in system settings.
  static Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod('isAccessibilityEnabled') as bool? ??
        false;
  }

  /// Opens the system Accessibility settings screen so the user can enable us.
  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  /// Whether the "draw over other apps" permission is granted.
  static Future<bool> canDrawOverlays() async {
    return await _channel.invokeMethod('canDrawOverlays') as bool? ?? false;
  }

  /// Opens the system overlay-permission screen for this app.
  static Future<void> openOverlaySettings() async {
    await _channel.invokeMethod('openOverlaySettings');
  }

  /// Whether "Usage access" is granted (needed to reliably read the foreground
  /// app, especially under realme/Oppo Game Space).
  static Future<bool> hasUsageAccess() async {
    return await _channel.invokeMethod('hasUsageAccess') as bool? ?? false;
  }

  /// Opens the system "Usage access" settings screen.
  static Future<void> openUsageAccessSettings() async {
    await _channel.invokeMethod('openUsageAccessSettings');
  }

  /// Whether this app is exempt from battery optimization. Recommended (not
  /// required) — some OEMs kill the background accessibility service without it.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    return await _channel.invokeMethod('isIgnoringBatteryOptimizations')
            as bool? ??
        true;
  }

  /// Opens the system prompt/screen to exempt this app from battery optimization.
  static Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod('openBatteryOptimizationSettings');
  }
}
