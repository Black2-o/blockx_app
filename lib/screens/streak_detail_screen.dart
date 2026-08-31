import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blockx/providers/block_providers.dart';
import 'package:blockx/providers/streak_provider.dart';
import 'package:blockx/theme/app_spacing.dart';
import 'package:blockx/widgets/app_scaffold.dart';
import 'package:blockx/widgets/streak_widgets.dart';
import 'package:blockx/screens/streak_screen.dart';

/// One streak, in full: the gradient hero, a pageable month calendar of the
/// days kept, and the next milestone. Reached by tapping a streak on the
/// Streak tab. Everything is derived from the streak's start date (see
/// [StreakStore]) — no extra backend state.
class StreakDetailScreen extends ConsumerWidget {
  const StreakDetailScreen({super.key, required this.id});

  /// App package name or feature key (e.g. `ig_reels`).
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streaks = ref.watch(streaksProvider);
    final notifier = ref.read(streaksProvider.notifier);

    final feature = StreakScreen.featureMeta[id];
    final isFeature = feature != null;
    final start = streaks[id] ?? DateTime.now();
    final days = streaks.containsKey(id) ? notifier.daysFor(id) : 1;
    final record = notifier.recordFor(id);

    final title = isFeature
        ? feature.$1
        : ref
            .watch(appNameProvider(id))
            .maybeWhen(data: (n) => n, orElse: () => id);

    return AppScaffold(
      title: title,
      padded: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPad,
          AppSpacing.lg,
          AppSpacing.screenPad,
          AppSpacing.xxxl,
        ),
        children: [
          StreakHeroCard(
            days: days,
            record: record,
            title: title,
            start: start,
            packageName: isFeature ? null : id,
            featureIcon: isFeature ? feature.$2 : null,
            showWeek: false,
            detail: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          StreakCalendar(start: start),
          const SizedBox(height: AppSpacing.lg),
          MilestoneCard(days: days),
        ],
      ),
    );
  }
}
