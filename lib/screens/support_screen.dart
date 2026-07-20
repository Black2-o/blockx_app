import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/cards.dart';

/// Support Us: UI only — no backend, and (for now) no external links. The links
/// will be added later once the real destinations exist.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Support Us',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Keep BlockX free', style: AppText.titleL),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'BlockX is a solo, ad-free project. If it helps you stay focused, a '
            'small gesture goes a long way.',
            style: AppText.bodyDim,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smAll,
                  ),
                  child: const Icon(Icons.favorite_outline,
                      color: AppColors.red, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('More ways to support are coming soon',
                          style: AppText.label),
                      const SizedBox(height: 2),
                      Text('Donate, share and rate links will appear here.',
                          style: AppText.bodyDim),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
