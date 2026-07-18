import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/block_config.dart';
import '../providers/block_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/cards.dart';
import '../widgets/celebration.dart';
import '../widgets/state_indicators.dart';
import 'config_sheet.dart';

/// Manage in-app feature blocks (Shorts / Reels). Turning one on always asks for
/// the block type first (Strict / Limit), just like adding an app. Backed by the
/// frozen [featureBlocksProvider] with the unchanged `yt_shorts` / `ig_reels` /
/// `fb_reels` keys.
class FeaturesScreen extends ConsumerWidget {
  const FeaturesScreen({super.key, this.embedded = false});

  final bool embedded;

  // (key, label, icon) — key must match native `featureApps` + FeatureStore.
  static const List<(String, String, IconData)> _items = [
    ('yt_shorts', 'YouTube Shorts', Icons.smart_display_outlined),
    ('ig_reels', 'Instagram Reels', Icons.movie_outlined),
    ('fb_reels', 'Facebook Reels', Icons.slideshow_outlined),
  ];

  Future<void> _configure(
    BuildContext context,
    WidgetRef ref,
    String key,
    String label,
    BlockConfig current,
  ) async {
    final updated = await showRuleConfigSheet(
      context,
      appName: label,
      initial: current.copyWith(enabled: true),
    );
    if (updated == null) return;
    await ref
        .read(featureBlocksProvider.notifier)
        .setConfig(key, updated.copyWith(enabled: true));
    if (!context.mounted) return;
    // Only celebrate when it wasn't already on (a fresh block).
    if (!current.enabled) {
      await showBlockCelebration(
        context,
        title: label,
        subtitle: updated.mode == BlockMode.timed ? 'Limited.' : 'Locked in.',
        accent:
            updated.mode == BlockMode.timed ? AppColors.amber : AppColors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(featureBlocksProvider);
    final notifier = ref.read(featureBlocksProvider.notifier);

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.lg,
        embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.xl,
      ),
      children: [
        Text(
          'Blocks just the short-video section inside these apps — the rest of '
          'the app keeps working. Tap one to pick Strict Block or Limit.',
          style: AppText.bodyDim,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final (key, label, icon) in _items) ...[
          _FeatureCard(
            label: label,
            icon: icon,
            config: configs[key] ?? const BlockConfig(enabled: false),
            onTap: () => _configure(context, ref, key, label,
                configs[key] ?? const BlockConfig(enabled: false)),
            onTurnOff: () => notifier.setEnabled(key, false),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );

    if (embedded) return body;
    return AppScaffold(title: 'Shorts & Reels', padded: false, body: body);
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.label,
    required this.icon,
    required this.config,
    required this.onTap,
    required this.onTurnOff,
  });

  final String label;
  final IconData icon;
  final BlockConfig config;
  final VoidCallback onTap;
  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    final on = config.enabled;
    return AppCard(
      onTap: onTap,
      glow: on,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: on ? AppColors.red : AppColors.textDim, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.label),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    StateBadge.forConfig(config),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        on ? config.summary : 'Tap to block',
                        style: AppText.bodyDim,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (on)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.textDim),
              tooltip: 'Turn off',
              onPressed: onTurnOff,
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.textDim),
        ],
      ),
    );
  }
}
