import 'package:hive_flutter/hive_flutter.dart';

/// UI-only persistence for block streaks. Two Hive boxes, both keyed by an item
/// id (app package **or** feature key like `yt_shorts`):
///  - `streaks`        : id -> epoch-millis when the current streak began.
///  - `streak_records` : id -> the longest streak (in days) ever reached, which
///                       survives unblocking/re-blocking so "best ever" is a
///                       true lifetime record.
/// Entirely separate from the blocking backend (block list, native prefs) — it
/// only powers the Streak screen.
class StreakStore {
  StreakStore(this._box, this._records);

  static const String boxName = 'streaks';
  static const String recordsBoxName = 'streak_records';

  final Box<int> _box;
  final Box<int> _records;

  static Future<StreakStore> open() async {
    final box = await Hive.openBox<int>(boxName);
    final records = await Hive.openBox<int>(recordsBoxName);
    return StreakStore(box, records);
  }

  /// id -> streak start (epoch millis).
  Map<String, int> readAll() =>
      _box.toMap().map((k, v) => MapEntry(k as String, v));

  Future<void> put(String id, int startMillis) => _box.put(id, startMillis);

  Future<void> remove(String id) => _box.delete(id);

  /// id -> best streak days ever reached (persists across unblock/re-block).
  Map<String, int> readRecords() =>
      _records.toMap().map((k, v) => MapEntry(k as String, v));

  Future<void> putRecord(String id, int days) => _records.put(id, days);
}
