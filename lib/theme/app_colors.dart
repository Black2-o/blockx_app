import 'package:flutter/material.dart';

/// The single source of truth for every color in BlockX.
///
/// Values and usage rules come from the UI/UX master prompt (§E). Never write a
/// raw hex anywhere else in the app — always reference a token here.
///
/// Contrast rules baked in:
///  - [red] is never small body text on dark; only ≥14sp bold / ≥18sp regular,
///    icons, borders, glows, or button *fills*.
///  - Any text sitting on a solid [red]/[amber] fill must be [white], not [text].
///  - Body text sits on [dark2]/[dark3], never directly on pure [dark]
///    (halation fix).
abstract final class AppColors {
  /// Borders, icons, glows, badges (≥14sp bold), button FILLS. Never small text.
  static const Color red = Color(0xFFE8000D);

  /// Friction / interstitial states only — never a hard block.
  static const Color amber = Color(0xFFFFB020);

  /// "Unlimited / allowed" indicator only, used sparingly.
  static const Color emerald = Color(0xFF34D399);

  /// Outermost app background only.
  static const Color dark = Color(0xFF080808);

  /// Primary surface: cards, sheets, bottom nav. Body text sits here.
  static const Color dark2 = Color(0xFF111111);

  /// Input fields.
  static const Color dark3 = Color(0xFF161010);

  /// Subtle raised fills.
  static const Color surface = Color(0x0AFFFFFF); // rgba(255,255,255,0.04)

  /// Default hairline borders.
  static const Color border = Color(0x14FFFFFF); // rgba(255,255,255,0.08)

  /// Red-glowing card / border accent.
  static const Color borderRed = Color(0x4DE8000D); // rgba(232,0,13,0.30)

  /// Default text color. 14sp floor.
  static const Color text = Color(0xFFF0E0E0);

  /// Secondary text, hints, captions.
  static const Color textDim = Color(0x80F0C8C8); // rgba(240,200,200,0.5)

  /// REQUIRED for any text on a solid red/amber fill (contrast fix).
  static const Color white = Color(0xFFFFFFFF);
}
