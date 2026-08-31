/// One app's foreground time today, from the native UsageStats reader.
class AppUsage {
  const AppUsage({
    required this.packageName,
    required this.appName,
    required this.totalTime,
  });

  final String packageName;
  final String appName;
  final Duration totalTime;

  factory AppUsage.fromMap(Map<dynamic, dynamic> map) {
    return AppUsage(
      packageName: (map['packageName'] as String?) ?? '',
      appName: (map['appName'] as String?) ?? '',
      totalTime: Duration(milliseconds: (map['totalTimeMs'] as num?)?.toInt() ?? 0),
    );
  }

  /// Human label like "1h 12m" or "8m".
  String get label => formatUsage(totalTime);
}

/// Total foreground time for a single day — one bar in the week chart.
class DayTotal {
  const DayTotal({required this.day, required this.total});

  /// Local midnight of the day.
  final DateTime day;
  final Duration total;

  factory DayTotal.fromMap(Map<dynamic, dynamic> map) {
    return DayTotal(
      day: DateTime.fromMillisecondsSinceEpoch(
          (map['dayStartMs'] as num?)?.toInt() ?? 0),
      total: Duration(milliseconds: (map['totalMs'] as num?)?.toInt() ?? 0),
    );
  }
}

/// Shared "1h 12m" / "8m" / "45s" formatter for any usage [Duration].
String formatUsage(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${d.inSeconds}s';
}
