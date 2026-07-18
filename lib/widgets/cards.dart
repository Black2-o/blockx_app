import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The standard surface container: [AppColors.dark2] fill, hairline border,
/// radius 12, 16 padding. Elevation is expressed by color + border, not shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.glow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Adds a subtle red border accent (used sparingly for emphasis).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.dark2,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.borderRed,
        highlightColor: AppColors.surface,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: glow ? AppColors.borderRed : AppColors.border,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A titled group header (Oswald 600 uppercase) with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(
      top: AppSpacing.xl,
      bottom: AppSpacing.md,
    ),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppText.sectionHeader,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
