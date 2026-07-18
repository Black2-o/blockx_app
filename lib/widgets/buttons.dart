import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The single red-fill call-to-action per screen (Von Restorff / Hick's Law).
/// White label, 48dp min height, full-width by default.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.color = AppColors.red,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  /// Override for the rare amber CTA (interstitial "Open"); defaults to red.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.dark3,
        disabledForegroundColor: AppColors.textDim,
        // Size(0, h) — NOT Size.fromHeight(h), which sets minWidth to infinity
        // and crashes when this button sits in an unbounded-width Row. Full-width
        // is provided by the SizedBox wrapper below instead.
        minimumSize: const Size(0, AppSpacing.tapTarget),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        textStyle: AppText.button,
      ),
      // No Flexible here: a Flexible child fails to lay out when the button is
      // placed in an unbounded-width parent (e.g. a Row). Full-width buttons get
      // their bound from the SizedBox below; compact buttons shrink-wrap.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.white),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label.toUpperCase(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A de-emphasized secondary action: a plain text link, never a second filled
/// button. Keeps exactly one primary CTA per screen.
class SecondaryLink extends StatelessWidget {
  const SecondaryLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.textDim,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(AppSpacing.tapTarget, AppSpacing.tapTarget),
      ),
      child: Text(label, style: AppText.label.copyWith(color: color)),
    );
  }
}
