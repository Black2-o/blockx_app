import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A streak milestone tier: the day threshold, its label, and the accent it
/// unlocks. Higher tiers drive a more energetic flame animation.
class StreakMilestone {
  const StreakMilestone(this.days, this.label, this.color, this.tier);

  final int days;
  final String label;
  final Color color;
  final int tier;
}

/// The milestone ladder. Amber early, red mid, emerald for the long hauls.
abstract final class StreakLevels {
  static const List<StreakMilestone> tiers = [
    StreakMilestone(1, 'Day one', AppColors.amber, 0),
    StreakMilestone(3, '3-day streak', AppColors.amber, 1),
    StreakMilestone(5, '5-day streak', AppColors.amber, 2),
    StreakMilestone(7, 'One week', AppColors.red, 3),
    StreakMilestone(15, '15-day streak', AppColors.red, 4),
    StreakMilestone(30, 'One month', AppColors.emerald, 5),
    StreakMilestone(60, 'Two months', AppColors.emerald, 6),
    StreakMilestone(100, '100 days', AppColors.emerald, 7),
    StreakMilestone(365, 'One year', AppColors.emerald, 8),
  ];

  /// The highest milestone reached at [days] (never null; day 0/1 → first tier).
  static StreakMilestone current(int days) {
    var reached = tiers.first;
    for (final t in tiers) {
      if (days >= t.days) reached = t;
    }
    return reached;
  }

  /// The next milestone above [days], or null once maxed out.
  static StreakMilestone? next(int days) {
    for (final t in tiers) {
      if (t.days > days) return t;
    }
    return null;
  }
}
