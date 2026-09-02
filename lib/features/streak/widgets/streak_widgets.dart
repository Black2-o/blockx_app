import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blockx/features/streak/models/streak.dart';
import 'package:blockx/core/providers/block_providers.dart';
import 'package:blockx/features/screen_time/screens/progress_screen.dart';
import 'package:blockx/core/theme/app_colors.dart';
import 'package:blockx/core/theme/app_spacing.dart';
import 'package:blockx/core/theme/app_typography.dart';
import 'package:blockx/core/widgets/app_icon.dart';

// The Streak screens' building blocks live in the `streak/` folder, split one
// widget per file for readability. They're `part` files of this library so they
// share the private helpers below (`_dayOnly`, `_DayState`, `_stateFor`,
// `kFlameGradient`) without changing any behaviour. Import this file to get all
// of them, exactly as before.
part 'streak/streak_hero.dart';
part 'streak/week_strip.dart';
part 'streak/streak_list_card.dart';
part 'streak/milestone_card.dart';
part 'streak/streak_calendar.dart';
part 'streak/screen_time_card.dart';

/// A streak is contiguous by definition (it resets to 0 the moment an app is
/// unblocked), so every day from its start date to today was "kept". That lets
/// the week strip and the calendar be derived purely from the start [DateTime]
/// already stored in [StreakStore] — no per-day backend log needed.

/// The flame gradient used to fill a "kept" day mark. Colours come from
/// [AppColors.flameGradient] — the single source of truth.
const LinearGradient kFlameGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: AppColors.flameGradient,
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
