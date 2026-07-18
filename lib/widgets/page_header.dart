import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A lightweight themed top bar (Oswald title, optional back + actions). Used by
/// [AppScaffold] and by the bottom-nav tab screens so headers look identical
/// everywhere without a raw Material AppBar.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.leading,
  });

  final String title;
  final List<Widget>? actions;
  final bool showBack;

  /// Replaces the whole leading+title area (e.g. the Home logo wordmark).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && Navigator.of(context).canPop();
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (leading != null)
            Expanded(child: leading!)
          else ...[
            if (canPop)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.text),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            else
              const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: AppText.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          ...?actions,
        ],
      ),
    );
  }
}
