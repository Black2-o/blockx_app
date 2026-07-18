import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/app_info.dart';
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
}
