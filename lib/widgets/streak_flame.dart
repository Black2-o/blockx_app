import 'package:flutter/material.dart';

import '../models/streak.dart';

/// A clean, static flame badge whose colour reflects the streak tier
/// (amber → red → emerald). No glow, blur, sparks or pulse — just a flame on a
/// flat tinted disc, so it reads as a simple, solid milestone marker.
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.days, this.size = 64});

  final int days;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = StreakLevels.current(days);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: m.color.withValues(alpha: 0.12),
        border: Border.all(color: m.color.withValues(alpha: 0.35)),
      ),
      child: Icon(
        Icons.local_fire_department,
        color: m.color,
        size: size * 0.5,
      ),
    );
  }
}

/// Small chip showing the current milestone label with its colour.
class StreakMilestoneChip extends StatelessWidget {
  const StreakMilestoneChip({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final m = StreakLevels.current(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: m.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        m.label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Oswald',
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.5,
          color: m.color,
        ),
      ),
    );
  }
}
