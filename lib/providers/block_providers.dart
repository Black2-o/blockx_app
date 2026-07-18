import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/block_store.dart';
import '../data/feature_store.dart';
import '../data/site_store.dart';
import '../models/app_info.dart';
import '../models/block_config.dart';
import '../services/block_platform.dart';

/// Provides the opened [BlockStore]. Overridden in `main()` once Hive is ready.
final blockStoreProvider = Provider<BlockStore>((ref) {
  throw UnimplementedError('blockStoreProvider must be overridden in main()');
});

/// The list of every launchable app installed on the device (loaded natively).
/// Used by the app picker, and to resolve display names on the home screen.
final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) {
  return BlockPlatform.getInstalledApps();
});

/// The block list: `packageName -> BlockConfig`. This is the app's core state.
final blockListProvider =
    StateNotifierProvider<BlockListNotifier, Map<String, BlockConfig>>((ref) {
  return BlockListNotifier(ref.watch(blockStoreProvider));
});

/// Whether the permissions the blocker needs are granted.
final permissionsProvider = FutureProvider<BlockPermissions>((ref) async {
  final accessibility = await BlockPlatform.isAccessibilityEnabled();
  final overlay = await BlockPlatform.canDrawOverlays();
  final usageAccess = await BlockPlatform.hasUsageAccess();
  return BlockPermissions(
    accessibility: accessibility,
    overlay: overlay,
    usageAccess: usageAccess,
  );
});

class BlockPermissions {
  const BlockPermissions({
    required this.accessibility,
    required this.overlay,
    required this.usageAccess,
  });

  final bool accessibility;
  final bool overlay;
  final bool usageAccess;

  bool get allGranted => accessibility && overlay && usageAccess;
}

/// Provides the opened [SiteStore]. Overridden in `main()` once Hive is ready.
final siteStoreProvider = Provider<SiteStore>((ref) {
  throw UnimplementedError('siteStoreProvider must be overridden in main()');
});

/// The blocked website domains. Mirrored to native on every change.
final blockedSitesProvider =
    StateNotifierProvider<BlockedSitesNotifier, List<String>>((ref) {
  return BlockedSitesNotifier(ref.watch(siteStoreProvider));
});

class BlockedSitesNotifier extends StateNotifier<List<String>> {
  BlockedSitesNotifier(this._store) : super(_store.readAll()) {
    _syncNative();
  }

  final SiteStore _store;

  /// Normalizes user input to a bare host: lowercase, no scheme/`www.`/path.
  /// e.g. "https://www.YouTube.com/feed" -> "youtube.com".
  static String normalize(String input) {
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return s;
    s = s.replaceFirst(RegExp(r'^[a-z]+://'), '');
    if (s.startsWith('www.')) s = s.substring(4);
    s = s.split('/').first.split('?').first.split('#').first;
    return s.trim();
  }

  /// Adds a domain (normalized). No-op for blank or already-present hosts.
  Future<void> addSite(String input) async {
    final host = normalize(input);
    if (host.isEmpty || state.contains(host)) return;
    await _store.add(host);
    state = [...state, host]..sort();
    await _syncNative();
  }

  /// Removes a blocked domain.
  Future<void> removeSite(String host) async {
    await _store.remove(host);
    state = [...state]..remove(host);
    await _syncNative();
  }

  Future<void> _syncNative() async {
    try {
      await BlockPlatform.setBlockedSites(state);
    } catch (_) {
      // Ignore: e.g. running under `flutter test`.
    }
  }
}

/// Provides the opened [FeatureStore]. Overridden in `main()`.
final featureStoreProvider = Provider<FeatureStore>((ref) {
  throw UnimplementedError('featureStoreProvider must be overridden in main()');
});

/// In-app sub-feature configs (`yt_shorts` / `ig_reels` / `fb_reels`), each a
/// [BlockConfig] (off / direct / timed). Mirrored to native on every change
/// (only the enabled ones).
final featureBlocksProvider =
    StateNotifierProvider<FeatureBlocksNotifier, Map<String, BlockConfig>>((ref) {
  return FeatureBlocksNotifier(ref.watch(featureStoreProvider));
});

class FeatureBlocksNotifier extends StateNotifier<Map<String, BlockConfig>> {
  FeatureBlocksNotifier(this._store) : super(_store.readAll()) {
    _syncNative();
  }

  final FeatureStore _store;

  /// Replace a feature's whole config (mode/opens/minutes + enabled).
  Future<void> setConfig(String key, BlockConfig config) async {
    await _store.put(key, config);
    state = {...state, key: config};
    await _syncNative();
  }

  /// Turn a feature on/off, keeping its mode/opens/minutes.
  Future<void> setEnabled(String key, bool enabled) async {
    final current = state[key] ?? const BlockConfig(enabled: false);
    await setConfig(key, current.copyWith(enabled: enabled));
  }

  Future<void> _syncNative() async {
    try {
      final enabled = <String, BlockConfig>{
        for (final e in state.entries)
          if (e.value.enabled) e.key: e.value,
      };
      await BlockPlatform.setFeatureBlocks(enabled);
    } catch (_) {
      // Ignore: e.g. running under `flutter test`.
    }
  }
}

class BlockListNotifier extends StateNotifier<Map<String, BlockConfig>> {
  BlockListNotifier(this._store) : super(_store.readAll()) {
    // Make the native service reflect whatever was persisted last run.
    _syncNative();
  }

  final BlockStore _store;

  /// Adds (or replaces) an app in the block list with the given config.
  Future<void> putApp(String packageName, BlockConfig config) async {
    await _store.put(packageName, config);
    state = {...state, packageName: config};
    await _syncNative();
  }

  /// Turns blocking for an app on or off (keeps it in the list either way).
  Future<void> setEnabled(String packageName, bool enabled) async {
    final current = state[packageName];
    if (current == null) return;
    await putApp(packageName, current.copyWith(enabled: enabled));
  }

  /// Removes an app from the list entirely.
  Future<void> removeApp(String packageName) async {
    await _store.remove(packageName);
    final next = {...state}..remove(packageName);
    state = next;
    await _syncNative();
  }

  Future<void> _syncNative() async {
    // Never let a native hiccup take down the UI state; the list is still
    // persisted regardless.
    try {
      final enabled = <String, BlockConfig>{
        for (final e in state.entries)
          if (e.value.enabled) e.key: e.value,
      };
      await BlockPlatform.setConfigs(enabled);
    } catch (_) {
      // Ignore: e.g. running under `flutter test`.
    }
  }
}
