import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Font families (bundled locally in `assets/fonts/`, declared in pubspec).
abstract final class AppFonts {
  /// Hero moments only: logo wordmark, splash, big countdowns/stats.
  static const String bebas = 'BebasNeue';

  /// Titles, section headers, labels, buttons. Weights 400 + 600.
  static const String oswald = 'Oswald';

  /// Body copy, list items, descriptions, input text. 14sp floor.
  static const String barlow = 'BarlowCondensed';
}

/// Named text styles for the whole app (design-system §2). Screens reference
/// `AppText.title` etc. — never a raw [TextStyle].
///
/// Rules baked in: 14sp floor everywhere; red is never used here for small body
/// text (that's enforced by callers using [AppColors.text]).
abstract final class AppText {
  /// Hero — splash wordmark, the biggest moments. Bebas, uppercase, wide track.
  static const TextStyle hero = TextStyle(
    fontFamily: AppFonts.bebas,
    fontSize: 48,
    letterSpacing: 0.12 * 48,
    height: 1.0,
    color: AppColors.text,
  );

  /// Big number — timer countdowns, stat values. Bebas, tabular feel.
  static const TextStyle heroNumber = TextStyle(
    fontFamily: AppFonts.bebas,
    fontSize: 40,
    letterSpacing: 0.04 * 40,
    height: 1.0,
    color: AppColors.text,
  );

  /// Large page title. Oswald 600 uppercase.
  static const TextStyle titleL = TextStyle(
    fontFamily: AppFonts.oswald,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    letterSpacing: 0.08 * 24,
    color: AppColors.text,
  );

  /// Page title / card title. Oswald 600 uppercase.
  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.oswald,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    letterSpacing: 0.08 * 18,
    color: AppColors.text,
  );

  /// Section header. Oswald 600 uppercase, slightly smaller.
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: AppFonts.oswald,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    letterSpacing: 0.08 * 15,
    color: AppColors.text,
  );

  /// Sub-header / emphasis label. Oswald 400.
  static const TextStyle label = TextStyle(
    fontFamily: AppFonts.oswald,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    letterSpacing: 0.04 * 15,
    color: AppColors.text,
  );

  /// Body copy. Barlow Condensed 400, 16sp (comfortable reading).
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.barlow,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.35,
    color: AppColors.text,
  );

  /// Secondary body / captions. Barlow 400, dimmed. 14sp floor.
  static const TextStyle bodyDim = TextStyle(
    fontFamily: AppFonts.barlow,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.35,
    color: AppColors.textDim,
  );

  /// Emphasis inline body. Barlow 500.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: AppFonts.barlow,
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 1.35,
    color: AppColors.text,
  );

  /// Button label. Oswald 600 uppercase.
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.oswald,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    letterSpacing: 0.06 * 16,
    color: AppColors.white,
  );
}
