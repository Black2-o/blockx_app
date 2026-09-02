part of 'package:blockx/features/streak/widgets/streak_widgets.dart';

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
                        ? AppColors.white.withValues(alpha: 0.72)
                        : AppColors.textDim,
                  ),
                ),
                SizedBox(height: onHero ? 7 : 6),
                _mark(
                  _stateFor(monday.add(Duration(days: i)), startDay, today),
                ),
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
          color: onHero ? AppColors.white : null,
          gradient: onHero ? null : kFlameGradient,
        );
        child = Icon(
          Icons.check_rounded,
          size: onHero ? 14 : 11,
          color: onHero ? AppColors.red : AppColors.white,
        );
        break;
      case _DayState.today:
        deco = BoxDecoration(
          shape: shape,
          borderRadius: radius,
          border: Border.all(
            color: onHero ? AppColors.white : AppColors.amber,
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
              ? AppColors.white.withValues(alpha: 0.12)
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
