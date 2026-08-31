import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/block_config.dart';

/// Persistence for in-app sub-feature blocks (YouTube Shorts, Instagram Reels,
/// Facebook Reels): one Hive box `feature_blocks_v2` of `key -> BlockConfig`
/// JSON. Reuses [BlockConfig] (`enabled` + direct/timed + opens/minutes), so a
/// feature can be off, always-blocked, or time-limited — just like an app.
///
/// (Box is `_v2`: the original `feature_blocks` box held plain bools; this one
/// holds JSON configs. The old box is simply abandoned.)
class FeatureStore {
  FeatureStore(this._box);

  static const String boxName = 'feature_blocks_v2';

  /// The known feature keys, in display order. Must match native `featureApps`.
  static const List<String> keys = ['yt_shorts', 'ig_reels', 'fb_reels'];

  /// Feature key -> the package of the app it lives inside. Mirror of native
  /// `featureApps` (AppBlockerService.kt). Used to detect when a feature is
  /// "covered" by a full block on its parent app: while the parent app is
  /// blocked, the feature is subsumed — its card locks and it stops being
  /// separately enforced, but its stored config (and streak) stay frozen so it
  /// resurfaces intact once the app is unblocked.
  static const Map<String, String> parentPackage = {
    'yt_shorts': 'com.google.android.youtube',
    'ig_reels': 'com.instagram.android',
    'fb_reels': 'com.facebook.katana',
  };

  final Box<String> _box;

  static Future<FeatureStore> open() async {
    final box = await Hive.openBox<String>(boxName);
    return FeatureStore(box);
  }

  /// Config for every known feature (default: off, i.e. `enabled: false`).
  Map<String, BlockConfig> readAll() {
    final result = <String, BlockConfig>{};
    for (final key in keys) {
      final raw = _box.get(key);
      result[key] = raw == null
          ? const BlockConfig(enabled: false)
          : BlockConfig.fromMap(jsonDecode(raw) as Map<dynamic, dynamic>);
    }
    return result;
  }

  Future<void> put(String key, BlockConfig config) =>
      _box.put(key, jsonEncode(config.toMap()));
}
