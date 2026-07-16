import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/block_store.dart';
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
