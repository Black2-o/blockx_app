import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blockx/core/providers/block_providers.dart';
import 'package:blockx/features/streak/providers/streak_provider.dart';
import 'package:blockx/core/theme/app_colors.dart';
import 'package:blockx/core/theme/app_spacing.dart';
import 'package:blockx/core/theme/app_typography.dart';
import 'package:blockx/core/widgets/app_scaffold.dart';
import 'package:blockx/core/widgets/empty_state.dart';
import 'package:blockx/features/streak/widgets/streak_widgets.dart';
import 'package:blockx/features/streak/screens/streak_detail_screen.dart';

/// The Streak tab: a gradient flame hero for the longest streak, an at-a-glance
/// stats row, a screen-time shortcut, then a card per blocked app/feature —
/// each with its own week strip and a tap-through to the full history. Streaks
/// are UI-only (see StreakStore); the blocking backend is untouched.
class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key, this.embedded = false});

  final bool embedded;

  static const Map<String, (String, IconData)> featureMeta = {
    'yt_shorts': ('YouTube Shorts', Icons.smart_display_outlined),
    'ig_reels': ('Instagram Reels', Icons.movie_outlined),
    'fb_reels': ('Facebook Reels', Icons.slideshow_outlined),
  };

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  void _openDetail(String id) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => StreakDetailScreen(id: id)));
  }

  @override
  Widget build(BuildContext context) {
    final blockList = ref.watch(blockListProvider);
    final features = ref.watch(featureBlocksProvider);
    final streaks = ref.watch(streaksProvider);
    final notifier = ref.read(streaksProvider.notifier);

    final activeApps = {
      for (final e in blockList.entries)
        if (e.value.enabled) e.key,
    };
    final activeFeatures = {
      for (final e in features.entries)
        if (e.value.enabled) e.key,
    };
    final activeIds = {...activeApps, ...activeFeatures};

    // Keep streak records in sync with what's actually blocked, and bump the
    // all-time bests — both after the frame so we never write during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifier.reconcile(activeIds);
      notifier.updateRecords();
    });

    int daysFor(String id) =>
        streaks.containsKey(id) ? notifier.daysFor(id) : 1;
    DateTime startFor(String id) => streaks[id] ?? DateTime.now();
    bool isFeature(String id) => activeFeatures.contains(id);
    String titleFor(String id) {
      if (isFeature(id)) return StreakScreen.featureMeta[id]?.$1 ?? id;
      return ref
          .watch(appNameProvider(id))
          .maybeWhen(data: (n) => n, orElse: () => id);
    }

    final ordered = activeIds.toList()
      ..sort((a, b) => daysFor(b).compareTo(daysFor(a)));
    final hasStreaks = ordered.isNotEmpty;
    final totalDays = ordered.fold<int>(0, (sum, id) => sum + daysFor(id));
    final topDays = hasStreaks ? daysFor(ordered.first) : 0;
    final bestEver = notifier.bestEver > topDays ? notifier.bestEver : topDays;

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.lg,
        widget.embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.xxxl,
      ),
      children: [
        // Lead with the featured (longest) streak, like the reference apps.
        if (hasStreaks) ...[
          Builder(
            builder: (_) {
              final id = ordered.first;
              return StreakHeroCard(
                days: daysFor(id),
                record: notifier.recordFor(id),
                title: titleFor(id),
                start: startFor(id),
                packageName: isFeature(id) ? null : id,
                featureIcon: isFeature(id)
                    ? StreakScreen.featureMeta[id]?.$2
                    : null,
                onTap: () => _openDetail(id),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        _StatsRow(
          active: ordered.length,
          bestEver: bestEver,
          totalDays: totalDays,
        ),
        const SizedBox(height: AppSpacing.md),
        const ScreenTimeCard(),
        const SizedBox(height: AppSpacing.xl),

        Text('YOUR STREAKS', style: AppText.sectionHeader),
        const SizedBox(height: AppSpacing.md),

        if (!hasStreaks)
          const EmptyState(
            icon: Icons.local_fire_department_outlined,
            title: 'No streaks yet',
            subtitle: 'Block an app or reel to start your first streak.',
            compact: true,
          )
        else
          // The full list — including the streak featured in the hero above.
          for (final id in ordered) ...[
            StreakListCard(
              days: daysFor(id),
              start: startFor(id),
              title: titleFor(id),
              packageName: isFeature(id) ? null : id,
              featureIcon: isFeature(id)
                  ? StreakScreen.featureMeta[id]?.$2
                  : null,
              onTap: () => _openDetail(id),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
        child: body,
      );
    }
    return AppScaffold(title: 'Streak', padded: false, body: body);
  }
}

/// The three at-a-glance stats above the streak list.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.active,
    required this.bestEver,
    required this.totalDays,
  });

  final int active;
  final int bestEver;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.local_fire_department,
              value: '$active',
              label: 'Active',
              color: AppColors.red,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatTile(
              icon: Icons.emoji_events_outlined,
              value: '$bestEver',
              label: 'Best',
              color: AppColors.amber,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatTile(
              icon: Icons.calendar_today_outlined,
              value: '$totalDays',
              label: 'Total',
              color: AppColors.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppText.heroNumber.copyWith(
              fontSize: 24,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyDim.copyWith(fontSize: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
