import 'package:flutter/material.dart';

/// One 4px-based spacing scale plus radii. No magic numbers in screens — always
/// reference these tokens (UI/UX master prompt / design-system §3).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard screen edge padding.
  static const double screenPad = lg;

  /// Minimum tap target (Fitts's Law) — width and height.
  static const double tapTarget = 48;

  /// Max readable content width; content wider than this is centered (tablets,
  /// landscape). Prevents lines stretching edge-to-edge.
  static const double maxContentWidth = 520;
}

/// Corner radii.
abstract final class AppRadius {
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
  static const Radius lg = Radius.circular(20);

  static const BorderRadius smAll = BorderRadius.all(sm);
  static const BorderRadius mdAll = BorderRadius.all(md);
  static const BorderRadius lgAll = BorderRadius.all(lg);
}

/// Motion durations (master prompt §A.5 / §E): 150–300ms, nothing longer.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);

  /// Splash is the one exception — a deliberate first-run moment.
  static const Duration splash = Duration(milliseconds: 600);
}
