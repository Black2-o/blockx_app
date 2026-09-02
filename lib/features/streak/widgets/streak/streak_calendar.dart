part of 'package:blockx/features/streak/widgets/streak_widgets.dart';

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
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
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
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday % 7; // Sun=0
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
              Text(
                '${_months[_month.month - 1]} ${_month.year}'.toUpperCase(),
                style: AppText.sectionHeader,
              ),
              const Spacer(),
              _navBtn(Icons.chevron_left, () => _shift(-1)),
              const SizedBox(width: AppSpacing.sm),
              _navBtn(
                Icons.chevron_right,
                _atCurrentMonth ? null : () => _shift(1),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (final w in _wd)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: AppText.bodyDim.copyWith(
                        fontFamily: AppFonts.oswald,
                        fontSize: 10,
                      ),
                    ),
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
                child: Text(
                  'Kept days since ${_months[startDay.month - 1].substring(0, 3)} ${startDay.day}. Tap ‹ to see previous weeks.',
                  style: AppText.bodyDim.copyWith(fontSize: 12.5),
                ),
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
        child: Icon(
          icon,
          color: enabled
              ? AppColors.text
              : AppColors.textDim.withValues(alpha: 0.3),
          size: 18,
        ),
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
          child: Text(
            '${day.day}',
            style: AppText.bodyStrong.copyWith(
              color: AppColors.white,
              fontSize: 13,
            ),
          ),
        );
      case _DayState.today:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.amber, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: AppText.bodyStrong.copyWith(
              color: AppColors.white,
              fontSize: 13,
            ),
          ),
        );
      case _DayState.future:
      case _DayState.off:
        return Center(
          child: Text(
            '${day.day}',
            style: AppText.bodyDim.copyWith(fontSize: 13),
          ),
        );
    }
  }
}
