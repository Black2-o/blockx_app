import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/streak.dart';
import '../providers/block_providers.dart';
import '../screens/progress_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_icon.dart';

/// Shared building blocks for the redesigned Streak screens (overview + detail).
///
/// A streak is contiguous by definition (it resets to 0 the moment an app is
/// unblocked), so every day from its start date to today was "kept". That lets
/// the week strip and the calendar be derived purely from the start [DateTime]
/// already stored in [StreakStore] — no per-day backend log needed.

/// Warm red-dominant fill used for the hero panels. Amber only appears as a
/// glow behind the flame (see [StreakHeroCard]) so white text always reads.
const List<Color> _heroReds = [Color(0xFFFF3521), Color(0xFFE8000D), Color(0xFFB80008)];

/// The flame gradient used to fill a "kept" day mark.
const LinearGradient kFlameGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFF3521), Color(0xFFE8000D), Color(0xFFFFB020)],
  stops: [0.0, 0.58, 1.0],
);

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The state of a single day cell in a week strip / calendar.
enum _DayState { kept, today, future, off }

_DayState _stateFor(DateTime day, DateTime start, DateTime today) {
  final d = _dayOnly(day);
  if (d.isAtSameMomentAs(today)) return _DayState.today;
  if (d.isAfter(today)) return _DayState.future;
  if (!d.isBefore(start)) return _DayState.kept; // start <= d < today
  return _DayState.off;
}

// ---------------------------------------------------------------------------
// Hero panel
// ---------------------------------------------------------------------------

/// The big gradient flame panel. Used both as the featured streak on the
/// overview (with a week strip) and as the header on the detail screen (bigger
/// number, no strip).
class StreakHeroCard extends StatelessWidget {
  const StreakHeroCard({
    super.key,
    required this.days,
    required this.record,
    required this.title,
    required this.start,
    this.packageName,
    this.featureIcon,
    this.onTap,
    this.showWeek = true,
    this.detail = false,
  });

  final int days;
  final int record;
  final String title;
  final DateTime start;
  final String? packageName;
  final IconData? featureIcon;
  final VoidCallback? onTap;

  /// Show the Mon–Sun strip (overview featured card only).
  final bool showWeek;

  /// Detail variant: bigger number, "Current streak" kicker, no app tile.
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final numberSize = detail ? 84.0 : 72.0;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kicker
          if (detail)
            Text('Current streak',
                style: AppText.label.copyWith(color: Colors.white))
          else
            Row(
              children: [
                _appTile(),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          // Big number
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '$days'),
              TextSpan(text: 'd', style: TextStyle(fontSize: numberSize * 0.34)),
            ]),
            style: AppText.heroNumber.copyWith(
              fontSize: numberSize,
              color: Colors.white,
              height: 0.86,
              shadows: const [
                Shadow(color: Color(0x803C0003), blurRadius: 14, offset: Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail ? 'Days blocked · $title' : 'Day streak',
            style: AppText.button.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 13,
              letterSpacing: 0.14 * 13,
            ),
          ),
          if (showWeek) ...[
            const SizedBox(height: AppSpacing.lg),
            WeekStrip(start: start, onHero: true),
          ],
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgAll,
          gradient: const LinearGradient(
            begin: Alignment(-0.7, -1),
            end: Alignment(0.6, 1),
            colors: _heroReds,
            stops: [0.0, 0.52, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.45),
              blurRadius: 34,
              offset: const Offset(0, 16),
              spreadRadius: -18,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: Stack(
            children: [
              // Amber glow behind the flame (top-right).
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.85, -0.5),
                      radius: 0.95,
                      colors: [
                        AppColors.amber.withValues(alpha: 0.5),
                        AppColors.amber.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.55],
                    ),
                  ),
                ),
              ),
              // Faint decorative flame.
              Positioned(
                right: -18,
                top: -10,
                child: Icon(Icons.local_fire_department,
                    size: 150, color: Colors.white.withValues(alpha: 0.14)),
              ),
              // Dark scrim (lower-left) so the number always reads.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.9, 0.95),
                      radius: 1.2,
                      colors: [Color(0x9E3C0003), Color(0x003C0003)],
                      stops: [0.0, 0.6],
                    ),
                  ),
                ),
              ),
              // Best-ever badge.
              if (record > 0)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(detail ? 'Best $record' : '$record',
                            style: AppText.bodyStrong.copyWith(
                                color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _appTile() {
    if (packageName != null) {
      return AppIcon(packageName: packageName!, size: 24);
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(featureIcon ?? Icons.movie_outlined, color: Colors.white, size: 15),
    );
  }
}

// ---------------------------------------------------------------------------
// Week strip (Mon–Sun)
// ---------------------------------------------------------------------------

/// Seven day-marks for the current calendar week (Mon–Sun). [onHero] switches
/// between the white-on-gradient look (hero) and the flame-tile look (card).
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.start, this.onHero = false});

  final DateTime start;
  final bool onHero;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = _dayOnly(DateTime.now());
    final startDay = _dayOnly(start);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: Column(
              children: [
                Text(
                  _labels[i],
                  style: AppText.bodyDim.copyWith(
                    fontFamily: AppFonts.oswald,
                    fontSize: onHero ? 11 : 9,
                    color: onHero
                        ? Colors.white.withValues(alpha: 0.72)
                        : AppColors.textDim,
                  ),
                ),
                SizedBox(height: onHero ? 7 : 6),
                _mark(_stateFor(monday.add(Duration(days: i)), startDay, today)),
              ],
            ),
          ),
          if (i < 6) SizedBox(width: onHero ? 7 : 6),
        ],
      ],
    );
  }

  Widget _mark(_DayState state) {
    final size = onHero ? 23.0 : 19.0;
    final shape = onHero ? BoxShape.circle : BoxShape.rectangle;
    final radius = onHero ? null : BorderRadius.circular(7);

    BoxDecoration deco;
    Widget? child;
    switch (state) {
      case _DayState.kept:
        deco = BoxDecoration(
          shape: shape,
          borderRadius: radius,
          color: onHero ? Colors.white : null,
          gradient: onHero ? null : kFlameGradient,
        );
        child = Icon(Icons.check_rounded,
            size: onHero ? 14 : 11, color: onHero ? AppColors.red : Colors.white);
        break;
      case _DayState.today:
        deco = BoxDecoration(
          shape: shape,
          borderRadius: radius,
          border: Border.all(
            color: onHero ? Colors.white : AppColors.amber,
            width: 2,
          ),
        );
        break;
      case _DayState.future:
      case _DayState.off:
        deco = BoxDecoration(
          shape: shape,
          borderRadius: radius,
          color: onHero
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.dark3,
          border: onHero ? null : Border.all(color: AppColors.border),
        );
        break;
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: deco,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Compact streak card (overview list)
// ---------------------------------------------------------------------------

class StreakListCard extends ConsumerWidget {
  const StreakListCard({
    super.key,
    required this.days,
    required this.start,
    required this.title,
    this.packageName,
    this.featureIcon,
    this.onTap,
  });

  final int days;
  final DateTime start;
  final String title;
  final String? packageName;
  final IconData? featureIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTitle = packageName == null
        ? title
        : ref
            .watch(appNameProvider(packageName!))
            .maybeWhen(data: (n) => n, orElse: () => title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.dark2,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _icon(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.label),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StreakMilestoneChipSmall(days: days),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Constrain the strip so the tiles keep breathing room.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: WeekStrip(start: start),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$days',
                      style: AppText.heroNumber.copyWith(fontSize: 34, color: AppColors.text)),
                  Text(days == 1 ? 'DAY' : 'DAYS',
                      style: AppText.bodyDim.copyWith(
                          fontFamily: AppFonts.oswald, fontSize: 10, letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    if (packageName != null) {
      return AppIcon(packageName: packageName!, size: 40);
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(featureIcon ?? Icons.movie_outlined, color: AppColors.red, size: 22),
    );
  }
}

/// Small milestone chip (compact variant used on the list card).
class StreakMilestoneChipSmall extends StatelessWidget {
  const StreakMilestoneChipSmall({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final m = StreakLevels.current(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: m.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        m.label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.oswald,
          fontWeight: FontWeight.w600,
          fontSize: 9.5,
          letterSpacing: 0.8,
          color: m.color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Next-milestone card (detail)
// ---------------------------------------------------------------------------

class MilestoneCard extends StatelessWidget {
  const MilestoneCard({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final next = StreakLevels.next(days);
    if (next == null) {
      return _shell(
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: AppColors.emerald, size: 26),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text('Maxed out — legend.',
                  style: AppText.title.copyWith(color: AppColors.text)),
            ),
          ],
        ),
      );
    }
    final remaining = next.days - days;
    final progress = (days / next.days).clamp(0.0, 1.0);

    return _shell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _hex(next.days),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT MILESTONE',
                    style: AppText.bodyDim.copyWith(
                        fontFamily: AppFonts.oswald,
                        color: AppColors.red,
                        fontSize: 10,
                        letterSpacing: 1.4)),
                const SizedBox(height: 2),
                Text(next.label.toUpperCase(),
                    style: AppText.sectionHeader),
                const SizedBox(height: 3),
                Text('$remaining more day${remaining == 1 ? '' : 's'} to unlock',
                    style: AppText.bodyDim),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.dark3,
                    valueColor: const AlwaysStoppedAnimation(AppColors.red),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$days ', style: AppText.bodyStrong.copyWith(
                          fontFamily: AppFonts.oswald, fontSize: 11)),
                      TextSpan(text: '/ ${next.days}', style: AppText.bodyDim.copyWith(
                          fontFamily: AppFonts.oswald, fontSize: 11)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.dark2,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.borderRed),
        ),
        child: child,
      );

  Widget _hex(int label) => SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.red, width: 2),
              ),
            ),
            Text('$label',
                style: AppText.heroNumber.copyWith(fontSize: 20, color: Colors.white)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Pageable month calendar (detail)
// ---------------------------------------------------------------------------

class StreakCalendar extends StatefulWidget {
  const StreakCalendar({super.key, required this.start});

  final DateTime start;

  @override
  State<StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends State<StreakCalendar> {
  late DateTime _month; // first of the visible month

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const _wd = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  bool get _atCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final today = _dayOnly(DateTime.now());
    final startDay = _dayOnly(widget.start);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7; // Sun=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(_cell(DateTime(_month.year, _month.month, d), startDay, today));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 18),
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_months[_month.month - 1]} ${_month.year}'.toUpperCase(),
                  style: AppText.sectionHeader),
              const Spacer(),
              _navBtn(Icons.chevron_left, () => _shift(-1)),
              const SizedBox(width: AppSpacing.sm),
              _navBtn(Icons.chevron_right, _atCurrentMonth ? null : () => _shift(1)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final w in _wd)
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: AppText.bodyDim.copyWith(
                            fontFamily: AppFonts.oswald, fontSize: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9,
            crossAxisSpacing: 8,
            children: cells,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.amber, size: 14),
              const SizedBox(width: 7),
              Expanded(
                child: Text('Kept days since ${_months[startDay.month - 1].substring(0, 3)} ${startDay.day}. Tap ‹ to see previous weeks.',
                    style: AppText.bodyDim.copyWith(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.dark3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon,
            color: enabled ? AppColors.text : AppColors.textDim.withValues(alpha: 0.3),
            size: 18),
      ),
    );
  }

  Widget _cell(DateTime day, DateTime start, DateTime today) {
    final state = _stateFor(day, start, today);
    switch (state) {
      case _DayState.kept:
        return Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: kFlameGradient,
          ),
          alignment: Alignment.center,
          child: Text('${day.day}',
              style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 13)),
        );
      case _DayState.today:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.amber, width: 2),
          ),
          alignment: Alignment.center,
          child: Text('${day.day}',
              style: AppText.bodyStrong.copyWith(color: Colors.white, fontSize: 13)),
        );
      case _DayState.future:
      case _DayState.off:
        return Center(
          child: Text('${day.day}',
              style: AppText.bodyDim.copyWith(fontSize: 13)),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Screen-time shortcut
// ---------------------------------------------------------------------------

class ScreenTimeCard extends ConsumerWidget {
  const ScreenTimeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageStatsProvider);
    final (label, apps) = usageAsync.maybeWhen(
      data: (list) {
        final total = list.fold<Duration>(Duration.zero, (s, u) => s + u.totalTime);
        final h = total.inHours;
        final mm = total.inMinutes % 60;
        return (h > 0 ? '${h}h ${mm}m' : '${mm}m', list.length);
      },
      orElse: () => ('—', 0),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProgressScreen()),
        ),
        borderRadius: AppRadius.mdAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.dark2,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart, color: AppColors.red, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SCREEN TIME TODAY',
                        style: AppText.bodyDim.copyWith(
                            fontFamily: AppFonts.oswald, fontSize: 10.5, letterSpacing: 1.2)),
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: label, style: AppText.title),
                        if (apps > 0)
                          TextSpan(
                              text: '  · across $apps apps',
                              style: AppText.bodyDim.copyWith(fontSize: 14)),
                      ]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
