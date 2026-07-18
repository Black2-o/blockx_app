import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// The app-wide dark [ThemeData]. Wired into `MaterialApp` in `main.dart`.
///
/// No screen should rely on default Material styling (master prompt §E): the
/// switch, chip, button, and input themes are all overridden here so the plain
/// Material look never appears.
abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.red,
      onPrimary: AppColors.white,
      secondary: AppColors.amber,
      onSecondary: AppColors.white,
      surface: AppColors.dark2,
      onSurface: AppColors.text,
      error: AppColors.red,
      onError: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.dark,
      fontFamily: AppFonts.barlow,
      splashColor: AppColors.borderRed,
      highlightColor: AppColors.surface,

      textTheme: const TextTheme(
        headlineLarge: AppText.titleL,
        titleLarge: AppText.title,
        titleMedium: AppText.label,
        bodyLarge: AppText.body,
        bodyMedium: AppText.body,
        bodySmall: AppText.bodyDim,
        labelLarge: AppText.button,
      ),

      iconTheme: const IconThemeData(color: AppColors.text),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.white
              : AppColors.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.red
              : AppColors.dark3,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.red
              : AppColors.border,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.dark3,
        selectedColor: AppColors.red,
        disabledColor: AppColors.dark3,
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppText.label,
        secondaryLabelStyle: AppText.label.copyWith(color: AppColors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.dark3,
        hintStyle: AppText.body.copyWith(color: AppColors.textDim),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: AppColors.red, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.dark3,
          disabledForegroundColor: AppColors.textDim,
          // Size(0, h), not Size.fromHeight(h): the latter forces infinite min
          // width and crashes any bare ElevatedButton placed in a Row.
          minimumSize: const Size(0, AppSpacing.tapTarget),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          textStyle: AppText.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(AppSpacing.tapTarget, AppSpacing.tapTarget),
          textStyle: AppText.label,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.dark2,
        contentTextStyle: AppText.body,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
