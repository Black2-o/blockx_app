/// How an app in the block list is enforced.
enum BlockMode {
  /// Always blocked while [BlockConfig.enabled] — the plain "This app is
  /// blocked" screen, no way in.
  direct,

  /// Blockable but openable a limited number of times per day. Each open shows
  /// an "Is this really needed?" interstitial, then grants a fixed-length
  /// session before blocking again.
  timed,
}

/// Per-app blocking configuration. This is the value stored in the block list
/// (keyed by package name) and mirrored to the native side.
class BlockConfig {
  const BlockConfig({
    required this.enabled,
    this.mode = BlockMode.direct,
    this.opensPerDay = 5,
    this.sessionMinutes = 5,
  });

  /// Whether blocking is active for this app right now (the home-screen switch).
  final bool enabled;

  /// Direct block vs time-limited.
  final BlockMode mode;

  /// For [BlockMode.timed]: how many times per day the app may be opened.
  final int opensPerDay;

  /// For [BlockMode.timed]: how long each open lasts, in minutes.
  final int sessionMinutes;

  BlockConfig copyWith({
    bool? enabled,
    BlockMode? mode,
    int? opensPerDay,
    int? sessionMinutes,
  }) {
    return BlockConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      opensPerDay: opensPerDay ?? this.opensPerDay,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'mode': mode.name,
        'opensPerDay': opensPerDay,
        'sessionMinutes': sessionMinutes,
      };

  factory BlockConfig.fromMap(Map<dynamic, dynamic> map) {
    return BlockConfig(
      enabled: (map['enabled'] as bool?) ?? true,
      mode: BlockMode.values.firstWhere(
        (m) => m.name == map['mode'],
        orElse: () => BlockMode.direct,
      ),
      opensPerDay: (map['opensPerDay'] as num?)?.toInt() ?? 5,
      sessionMinutes: (map['sessionMinutes'] as num?)?.toInt() ?? 5,
    );
  }

  /// Short human summary for the home-screen row.
  String get summary {
    if (mode == BlockMode.direct) return 'Always blocked';
    return 'Timed · $opensPerDay×/day · $sessionMinutes min each';
  }
}
