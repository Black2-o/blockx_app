import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/streak.dart';
import '../providers/block_providers.dart';
import '../providers/streak_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/cards.dart';
import '../widgets/empty_state.dart';
import '../widgets/streak_flame.dart';
import 'progress_screen.dart';

/// The Streak tab: a hero for your best current streak, a quick stats row
/// (active / best-ever / total days), a screen-time summary, then the full list
/// of per-item streaks. Streaks are UI-only (see StreakStore) — the blocking
/// backend is untouched.
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

    final ordered = activeIds.toList()
      ..sort((a, b) => daysFor(b).compareTo(daysFor(a)));
    final hasStreaks = ordered.isNotEmpty;
    final totalDays = ordered.fold<int>(0, (sum, id) => sum + daysFor(id));
    final topDays = hasStreaks ? daysFor(ordered.first) : 0;
    // Best ever is at least the current best, so it never reads low on frame 1.
    final bestEver =
        notifier.bestEver > topDays ? notifier.bestEver : topDays;

    Widget streakCard(String id, {required bool featured}) {
      final isFeature = activeFeatures.contains(id);
      return _StreakCard(
        featured: featured,
        days: daysFor(id),
        record: notifier.recordFor(id),
        isFeature: isFeature,
        title: isFeature ? (StreakScreen.featureMeta[id]?.$1 ?? id) : id,
        packageName: isFeature ? null : id,
        featureIcon: StreakScreen.featureMeta[id]?.$2,
      );
    }

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.lg,
        widget.embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.xxxl,
      ),
      children: [
        // Always-visible overview so the tab never looks empty, even on day one.
        _StatsRow(
          active: ordered.length,
          bestEver: bestEver,
          totalDays: totalDays,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _ScreenTimeSummary(),
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
          // The longest streak is featured (bigger); the rest are compact.
          for (final (i, id) in ordered.indexed) ...[
            streakCard(id, featured: i == 0),
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

/// One streak entry. [featured] renders the big hero variant (larger flame +
/// number, accent border); otherwise a compact list row.
class _StreakCard extends ConsumerWidget {
  const _StreakCard({
    required this.days,
    required this.record,
    required this.featured,
    required this.isFeature,
    required this.title,
    required this.packageName,
    required this.featureIcon,
  });

  final int days;
  final int record;
  final bool featured;
  final bool isFeature;
  final String title;
  final String? packageName;
  final IconData? featureIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTitle = packageName == null
        ? title
        : ref
            .watch(appNameProvider(packageName!))
            .maybeWhen(data: (n) => n, orElse: () => title);
    final m = StreakLevels.current(days);
    final next = StreakLevels.next(days);
    final progress = next == null ? 1.0 : (days / next.days).clamp(0.0, 1.0);

    final flameSize = featured ? 72.0 : 52.0;
    final numberSize = featured ? 40.0 : 26.0;

    return AppCard(
      glow: featured,
      child: Row(
        children: [
          StreakFlame(days: days, size: flameSize),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (packageName != null)
                      AppIcon(packageName: packageName!, size: 20)
                    else
                      Icon(featureIcon ?? Icons.movie_outlined,
                          color: AppColors.textDim, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(displayTitle,
                          style: AppText.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (record > days) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _BestBadge(record: record),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$days',
                        style: AppText.heroNumber
                            .copyWith(fontSize: numberSize, color: m.color)),
                    const SizedBox(width: AppSpacing.xs),
                    Text(days == 1 ? 'DAY' : 'DAYS', style: AppText.bodyDim),
                    const SizedBox(width: AppSpacing.sm),
                    StreakMilestoneChip(days: days),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: AppColors.dark3,
                    valueColor: AlwaysStoppedAnimation(m.color),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  next == null
                      ? 'Maxed out — legend.'
                      : '${next.days - days} day${next.days - days == 1 ? '' : 's'} to ${next.label}',
                  style: AppText.bodyDim,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Little "all-time best" badge (trophy + record days) shown when a past streak
/// beat the current one.
class _BestBadge extends StatelessWidget {
  const _BestBadge({required this.record});

  final int record;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events_outlined,
            color: AppColors.amber, size: 14),
        const SizedBox(width: 3),
        Text('$record',
            style: AppText.bodyDim.copyWith(
              color: AppColors.amber,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
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
          Text(value,
              style: AppText.heroNumber
                  .copyWith(fontSize: 24, color: AppColors.text)),
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

/// Compact "screen time today" card that opens the full Screen Time page.
class _ScreenTimeSummary extends ConsumerWidget {
  const _ScreenTimeSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageStatsProvider);
    final label = usageAsync.maybeWhen(
      data: (list) {
        final total = list.fold<Duration>(
            Duration.zero, (sum, u) => sum + u.totalTime);
        final h = total.inHours;
        final mm = total.inMinutes % 60;
        return h > 0 ? '${h}h ${mm}m' : '${mm}m';
      },
      orElse: () => '—',
    );

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ProgressScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: const Icon(Icons.bar_chart, color: AppColors.red, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SCREEN TIME TODAY', style: AppText.bodyDim),
                const SizedBox(height: 2),
                Text(label, style: AppText.title),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textDim),
        ],
      ),
    );
  }
}
