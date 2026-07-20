import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/streak_store.dart';
import '../services/block_platform.dart';

/// Provides the opened [StreakStore]. Overridden in `main()` once Hive is ready.
final streakStoreProvider = Provider<StreakStore>((ref) {
  throw UnimplementedError('streakStoreProvider must be overridden in main()');
});

/// Per-item block-streak start dates (`id -> streak start day`). `id` is an app
/// package or a feature key. Reconciled against the currently-active blocks:
/// a newly blocked item starts a streak today; an unblocked item loses it.
class StreakNotifier extends StateNotifier<Map<String, DateTime>> {
  StreakNotifier(this._store) : super(_load(_store)) {
    _records = {..._store.readRecords()};
    // Push whatever was persisted so the native block screen has it on launch.
    _syncNative();
  }

  final StreakStore _store;

  /// id -> best streak days ever reached (all-time record, persisted).
  late Map<String, int> _records;

  /// The longest streak (days) ever reached for [id], or 0 if none.
  int recordFor(String id) => _records[id] ?? 0;

  /// The single highest streak ever reached across every item — the headline
  /// "best ever" number.
  int get bestEver {
    var best = 0;
    for (final v in _records.values) {
      if (v > best) best = v;
    }
    return best;
  }

  /// Bump each active item's all-time record when its current streak is longer.
  /// Safe to call after every build — only writes (and rebuilds) on a new best.
  void updateRecords() {
    var changed = false;
    for (final id in state.keys) {
      final current = daysFor(id);
      if (current > (_records[id] ?? 0)) {
        _records[id] = current;
        _store.putRecord(id, current);
        changed = true;
      }
    }
    // Reassign state to notify listeners so bestEver/recordFor refresh.
    if (changed) state = {...state};
  }

  static Map<String, DateTime> _load(StreakStore store) {
    return store.readAll().map(
          (id, ms) => MapEntry(id, DateTime.fromMillisecondsSinceEpoch(ms)),
        );
  }

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Ensure a streak exists for every active id and none for inactive ones.
  /// Safe to call after every build — it only writes when something changed.
  void reconcile(Set<String> activeIds) {
    final today = _dayOnly(DateTime.now());
    final next = {...state};
    var changed = false;

    for (final id in activeIds) {
      if (!next.containsKey(id)) {
        next[id] = today;
        _store.put(id, today.millisecondsSinceEpoch);
        changed = true;
      }
    }
    for (final id in state.keys.toList()) {
      if (!activeIds.contains(id)) {
        next.remove(id);
        _store.remove(id);
        changed = true;
      }
    }
    if (changed) {
      state = next;
      _syncNative();
    }
  }

  /// Mirror the current streak starts to native (best-effort; ignored under
  /// `flutter test` where the platform channel isn't available).
  Future<void> _syncNative() async {
    try {
      final payload = <String, int>{
        for (final e in state.entries) e.key: e.value.millisecondsSinceEpoch,
      };
      await BlockPlatform.setStreaks(payload);
    } catch (_) {
      // Ignore.
    }
  }

  /// Whole days on the current streak (day it started counts as day 1).
  int daysFor(String id) {
    final start = state[id];
    if (start == null) return 0;
    return _dayOnly(DateTime.now()).difference(_dayOnly(start)).inDays + 1;
  }
}

final streaksProvider =
    StateNotifierProvider<StreakNotifier, Map<String, DateTime>>((ref) {
  return StreakNotifier(ref.watch(streakStoreProvider));
});
