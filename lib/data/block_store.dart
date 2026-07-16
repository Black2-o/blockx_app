import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/block_config.dart';

/// Single source of truth for persistence: one Hive box mapping
/// `packageName -> BlockConfig` (stored as a JSON string per app).
///
/// "In the list" == there is a key for that package. Whether it's blocked right
/// now is [BlockConfig.enabled]; how it's blocked is the rest of the config.
class BlockStore {
  BlockStore(this._box);

  /// New box (v2) holds JSON configs. The old box `blocklist` held plain bools;
  /// its data is migrated once on first open.
  static const String boxName = 'blocklist_v2';
  static const String legacyBoxName = 'blocklist';

  final Box<String> _box;

  /// Opens (or creates) the config box, migrating any legacy bool entries.
  static Future<BlockStore> open() async {
    final box = await Hive.openBox<String>(boxName);
    await _migrateLegacy(box);
    return BlockStore(box);
  }

  /// If an old `Box<bool>` exists, fold each entry into the new box as a
  /// direct-mode config, then clear the legacy box so we don't re-migrate.
  static Future<void> _migrateLegacy(Box<String> box) async {
    if (!await Hive.boxExists(legacyBoxName)) return;
    final legacy = await Hive.openBox<bool>(legacyBoxName);
    for (final key in legacy.keys) {
      final pkg = key.toString();
      if (box.containsKey(pkg)) continue;
      final enabled = legacy.get(key) ?? false;
      final config = BlockConfig(enabled: enabled, mode: BlockMode.direct);
      await box.put(pkg, jsonEncode(config.toMap()));
    }
    await legacy.clear();
    await legacy.close();
  }

  /// Current package -> config map (a copy, safe to hand to the UI layer).
  Map<String, BlockConfig> readAll() {
    final result = <String, BlockConfig>{};
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        result[key.toString()] =
            BlockConfig.fromMap(jsonDecode(raw) as Map<dynamic, dynamic>);
      } catch (_) {
        // Skip a corrupt entry rather than crash the whole list.
      }
    }
    return result;
  }

  /// Adds or replaces a package's config.
  Future<void> put(String packageName, BlockConfig config) =>
      _box.put(packageName, jsonEncode(config.toMap()));

  /// Removes a package from the list entirely.
  Future<void> remove(String packageName) => _box.delete(packageName);
}
