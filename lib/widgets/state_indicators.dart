import 'package:flutter/material.dart';

import '../models/block_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A small pill that always pairs an ICON + TEXT LABEL + color — never color
/// alone (master prompt §A.4: ~8% of men have red-green CVD). Used for
/// Blocked / Timed / Off states on list rows and cards.
class StateBadge extends StatelessWidget {
  const StateBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  /// Blocked-directly: a hard, always-on block.
  factory StateBadge.blocked() => const StateBadge(
        icon: Icons.block,
        label: 'Blocked',
        color: AppColors.red,
      );

  /// Time-limited.
  factory StateBadge.timed() => const StateBadge(
        icon: Icons.hourglass_bottom,
        label: 'Timed',
        color: AppColors.amber,
      );

  /// Not currently enforced.
  factory StateBadge.off() => const StateBadge(
        icon: Icons.circle_outlined,
        label: 'Off',
        color: AppColors.textDim,
      );

  /// Allowed / unlimited (used sparingly).
  factory StateBadge.allowed() => const StateBadge(
        icon: Icons.check_circle_outline,
        label: 'Allowed',
        color: AppColors.emerald,
      );

  /// Derive the badge from a [BlockConfig] (respects the enabled flag).
  factory StateBadge.forConfig(BlockConfig config) {
    if (!config.enabled) return StateBadge.off();
    return config.mode == BlockMode.timed
        ? StateBadge.timed()
        : StateBadge.blocked();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            // ≥14sp bold satisfies the AA large-text threshold for colored text.
            style: AppText.bodyDim.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
