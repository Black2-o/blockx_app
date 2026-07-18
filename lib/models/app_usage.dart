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
  String get label {
    final h = totalTime.inHours;
    final m = totalTime.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${totalTime.inSeconds}s';
  }
}
