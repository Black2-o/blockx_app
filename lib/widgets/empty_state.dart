import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A "nothing here yet" placeholder: one simple icon + a line + optional
/// sub-line. Deliberately plain (no stock illustration — anti-slop §7).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Tighter variant for inline use inside a section (vs a full-screen centre).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? AppSpacing.xl : AppSpacing.xxxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 32 : 48, color: AppColors.textDim),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppText.label, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: AppText.bodyDim, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
