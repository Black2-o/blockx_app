import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blockx/models/app_usage.dart';
import 'package:blockx/providers/block_providers.dart';
import 'package:blockx/services/block_platform.dart';
import 'package:blockx/theme/app_colors.dart';
import 'package:blockx/theme/app_spacing.dart';
import 'package:blockx/theme/app_typography.dart';
import 'package:blockx/widgets/app_icon.dart';
import 'package:blockx/widgets/app_scaffold.dart';
import 'package:blockx/widgets/buttons.dart';
import 'package:blockx/widgets/decor.dart';
import 'package:blockx/widgets/empty_state.dart';

/// Screen Time: real per-app usage straight from Android UsageStats (the same
/// source as system Digital Wellbeing). A week bar chart up top, a selectable
/// day, and that day's per-app breakdown. Read-only; needs Usage Access.
/// History reaches only as far back as the OS keeps events (~7 days).
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(permissionsProvider);
    final hasUsage = permsAsync.asData?.value.usageAccess ?? false;

    final Widget content = hasUsage
        ? const _UsageView()
        : _NeedsPermission(
            onGranted: () => ref.invalidate(permissionsProvider),
          );

    if (embedded) return content;
    return AppScaffold(title: 'Screen Time', body: content, padded: false);
  }
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Week chart + day navigator + the selected day's per-app list.
class _UsageView extends ConsumerStatefulWidget {
  const _UsageView();

  @override
  ConsumerState<_UsageView> createState() => _UsageViewState();
}

class _UsageViewState extends ConsumerState<_UsageView> {
  late DateTime _weekStart; // first day (Saturday) of the displayed week
  late DateTime _selected; // selected day (never in the future)

  @override
  void initState() {
    super.initState();
    final today = _dayOnly(DateTime.now());
    _weekStart = _weekStartOf(today);
    _selected = today;
  }

  DateTime get _today => _dayOnly(DateTime.now());

  /// The Saturday on or before [d] — the week starts on Saturday.
  DateTime _weekStartOf(DateTime d) {
    final day = _dayOnly(d);
    final daysSinceSat = (day.weekday - DateTime.saturday + 7) % 7;
    return day.subtract(Duration(days: daysSinceSat));
  }

  // Four weeks total: this week plus three back.
  DateTime get _currentWeekStart => _weekStartOf(_today);
  DateTime get _earliestWeekStart =>
      _currentWeekStart.subtract(const Duration(days: 21));

  bool get _canPrevWeek => _weekStart.isAfter(_earliestWeekStart);
  bool get _canNextWeek => _weekStart.isBefore(_currentWeekStart);

  /// The latest day of [weekStart]'s week that isn't in the future.
  DateTime _lastSelectableOf(DateTime weekStart) {
    final lastDay = weekStart.add(const Duration(days: 6));
    return lastDay.isAfter(_today) ? _today : lastDay;
  }

  void _prevWeek() {
    if (!_canPrevWeek) return;
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _selected = _lastSelectableOf(_weekStart);
    });
  }

  void _nextWeek() {
    if (!_canNextWeek) return;
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _selected = _lastSelectableOf(_weekStart);
    });
  }

  void _selectDay(DateTime day) {
    final d = _dayOnly(day);
    if (d.isAfter(_today)) return;
    setState(() => _selected = d);
  }

  // Fine day stepper — moves across the whole 4-week range, pulling the
  // displayed week along when it crosses a boundary.
  DateTime get _earliestDay => _earliestWeekStart;
  bool get _canBackDay => _selected.isAfter(_earliestDay);
  bool get _canForwardDay => _selected.isBefore(_today);
  void _stepDay(int delta) {
    final next = _dayOnly(_selected.add(Duration(days: delta)));
    if (next.isAfter(_today) || next.isBefore(_earliestDay)) return;
    setState(() {
      _selected = next;
      _weekStart = _weekStartOf(next);
    });
  }

  String _dayLabel(DateTime day) {
    if (day == _today) return 'Today';
    if (day == _today.subtract(const Duration(days: 1))) return 'Yesterday';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[day.weekday - 1]}, ${day.day} ${_mon(day.month)}';
  }

  String _weekLabel() {
    if (_weekStart == _currentWeekStart) return 'This week';
    if (_weekStart == _currentWeekStart.subtract(const Duration(days: 7))) {
      return 'Last week';
    }
    final end = _weekStart.add(const Duration(days: 6));
    if (_weekStart.month == end.month) {
      return '${_weekStart.day}–${end.day} ${_mon(end.month)}';
    }
    return '${_weekStart.day} ${_mon(_weekStart.month)} – ${end.day} ${_mon(end.month)}';
  }

  static String _mon(int m) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

  @override
  Widget build(BuildContext context) {
    final weekAsync = ref.watch(weekTotalsProvider(_weekStart));
    final dayAsync = ref.watch(usageForDayProvider(_selected));

    return RefreshIndicator(
      color: AppColors.red,
      backgroundColor: AppColors.dark2,
      onRefresh: () async {
        ref.invalidate(weekTotalsProvider(_weekStart));
        ref.invalidate(usageForDayProvider(_selected));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPad,
          AppSpacing.lg,
          AppSpacing.screenPad,
          AppSpacing.xxxl,
        ),
        children: [
          _WeekChart(
            totals: weekAsync.asData?.value ?? const [],
            selected: _selected,
            today: _today,
            weekLabel: _weekLabel(),
            canPrevWeek: _canPrevWeek,
            canNextWeek: _canNextWeek,
            onPrevWeek: _prevWeek,
            onNextWeek: _nextWeek,
            onSelectDay: _selectDay,
          ),
          const SizedBox(height: AppSpacing.lg),
          _DayHeader(
            label: _dayLabel(_selected),
            total:
                dayAsync.asData?.value.fold<Duration>(
                  Duration.zero,
                  (s, u) => s + u.totalTime,
                ) ??
                Duration.zero,
            canBack: _canBackDay,
            canForward: _canForwardDay,
            onBack: () => _stepDay(-1),
            onForward: () => _stepDay(1),
          ),
          const SizedBox(height: AppSpacing.md),
          _dayBody(dayAsync),
        ],
      ),
    );
  }

  Widget _dayBody(AsyncValue<List<AppUsage>> dayAsync) {
    return dayAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator(color: AppColors.red)),
      ),
      error: (err, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not read usage',
        subtitle: '$err',
        compact: true,
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.timelapse,
            title: 'No usage this day',
            subtitle: 'Nothing was recorded, or the day is out of range.',
            compact: true,
          );
        }
        final maxMs = list.first.totalTime.inMilliseconds;
        return Column(
          children: [
            for (final u in list) ...[
              _UsageRow(usage: u, maxMs: maxMs),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

/// One week of 7 day-bars with a ‹ week › navigator and that week's daily
/// average. Tapping a past/today bar selects it; future days are shown dimmed
/// and are not tappable.
class _WeekChart extends StatelessWidget {
  const _WeekChart({
    required this.totals,
    required this.selected,
    required this.today,
    required this.weekLabel,
    required this.canPrevWeek,
    required this.canNextWeek,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onSelectDay,
  });

  final List<DayTotal> totals;
  final DateTime selected;
  final DateTime today;
  final String weekLabel;
  final bool canPrevWeek;
  final bool canNextWeek;
  final VoidCallback onPrevWeek;
  final VoidCallback onNextWeek;
  final ValueChanged<DateTime> onSelectDay;

  static const _barMax = 92.0;

  @override
  Widget build(BuildContext context) {
    final maxMs = totals.fold<int>(
      1,
      (m, t) => t.total.inMilliseconds > m ? t.total.inMilliseconds : m,
    );
    // Daily average over days that have actually happened (skip the future).
    final past = totals.where((t) => !_dayOnly(t.day).isAfter(today)).toList();
    final avg = past.isEmpty
        ? Duration.zero
        : Duration(
            milliseconds:
                past.fold<int>(0, (s, t) => s + t.total.inMilliseconds) ~/
                past.length,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _navBtn(Icons.chevron_left, canPrevWeek ? onPrevWeek : null),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      weekLabel.toUpperCase(),
                      style: AppText.sectionHeader,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily avg · ${formatUsage(avg)}',
                      style: AppText.bodyDim,
                    ),
                  ],
                ),
              ),
              _navBtn(Icons.chevron_right, canNextWeek ? onNextWeek : null),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (totals.isEmpty)
            const SizedBox(
              height: _barMax,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.red,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: SizedBox(
                height: _barMax + 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final t in totals) Expanded(child: _bar(t, maxMs)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) => IconButton(
    onPressed: onTap,
    icon: Icon(
      icon,
      size: 22,
      color: onTap == null
          ? AppColors.textDim.withValues(alpha: 0.3)
          : AppColors.text,
    ),
  );

  Widget _bar(DayTotal t, int maxMs) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final day = _dayOnly(t.day);
    final isFuture = day.isAfter(today);
    final isSel = day == _dayOnly(selected);
    final frac = (t.total.inMilliseconds / maxMs).clamp(0.0, 1.0);
    final h = (frac * _barMax).clamp(
      t.total.inMilliseconds > 0 ? 6.0 : 3.0,
      _barMax,
    );

    final col = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: isSel
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.redBright, AppColors.red],
                  )
                : null,
            color: isSel
                ? null
                : (isFuture
                      ? AppColors.dark3.withValues(alpha: 0.4)
                      : AppColors.dark3),
            border: isSel ? null : Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          labels[day.weekday - 1],
          style: AppText.bodyDim.copyWith(
            fontFamily: AppFonts.oswald,
            fontSize: 11,
            color: isSel
                ? AppColors.red
                : (isFuture
                      ? AppColors.textDim.withValues(alpha: 0.4)
                      : AppColors.textDim),
            fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );

    if (isFuture) return col; // future days aren't selectable
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelectDay(t.day),
      child: col,
    );
  }
}

/// Selected-day header: total time + a ‹ / › day stepper.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.total,
    required this.canBack,
    required this.canForward,
    required this.onBack,
    required this.onForward,
  });

  final String label;
  final Duration total;
  final bool canBack;
  final bool canForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: GlowBackground(
        alignment: Alignment.topRight,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.borderRed),
          ),
          child: Row(
            children: [
              _stepBtn(Icons.chevron_left, canBack ? onBack : null),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(label.toUpperCase(), style: AppText.bodyDim),
                    const SizedBox(height: 2),
                    Text(
                      formatUsage(total),
                      style: AppText.hero.copyWith(fontSize: 40),
                    ),
                  ],
                ),
              ),
              _stepBtn(Icons.chevron_right, canForward ? onForward : null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: onTap == null
            ? AppColors.textDim.withValues(alpha: 0.3)
            : AppColors.text,
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.usage, required this.maxMs});
  final AppUsage usage;
  final int maxMs;

  @override
  Widget build(BuildContext context) {
    final fraction = maxMs <= 0
        ? 0.0
        : (usage.totalTime.inMilliseconds / maxMs).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(packageName: usage.packageName, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  usage.appName,
                  style: AppText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                usage.label,
                style: AppText.bodyDim.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.dark3,
              valueColor: const AlwaysStoppedAnimation(AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsPermission extends StatelessWidget {
  const _NeedsPermission({required this.onGranted});
  final VoidCallback onGranted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 48, color: AppColors.textDim),
            const SizedBox(height: AppSpacing.md),
            Text('See your screen time', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Turn on Usage Access so BlockX can show how long you spend in '
              'each app, day by day.',
              style: AppText.bodyDim,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Allow Usage Access',
              fullWidth: false,
              onPressed: () async {
                await BlockPlatform.openUsageAccessSettings();
                onGranted();
              },
            ),
          ],
        ),
      ),
    );
  }
}
