import 'package:flutter/material.dart';

// ── Design system ─────────────────────────────────────────────────────────────
// One brand hue (blue) plus three fixed-meaning semantic hues — danger (severe),
// warning (mild/needs attention), success (safe/confirmed) — and a single
// secondary hue (violet) reserved for the guardian role badge. Every screen
// pulls from this same set; don't introduce ad-hoc colors in individual
// screens — extend this file instead so severity/role colors stay consistent
// app-wide.

class AppColors {
  // Light
  static const bg = Color(0xFFF7F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E9F2);
  static const textPrimary = Color(0xFF101828);
  static const textSecondary = Color(0xFF667085);
  static const textTertiary = Color(0xFF98A2B3);
  static const primary = Color(0xFF2563EB);
  static const primaryPressed = Color(0xFF1D4ED8);
  static const primaryTint = Color(0xFFEBF2FE);
  static const success = Color(0xFF16A34A);
  static const successTint = Color(0xFFEDFBF1);
  static const danger = Color(0xFFDC2626);
  static const dangerPressed = Color(0xFFB91C1C);
  static const dangerTint = Color(0xFFFDECEC);
  static const warning = Color(0xFFD97706);
  // brightened from the old brown 0xFF92400E — keeps 4.5:1 contrast on white
  static const warningText = Color(0xFFB45309);
  static const warningTint = Color(0xFFFEF6E7);
  // secondary hue — guardian role badge only, not severity
  static const accent = Color(0xFF7C3AED);
  static const accentTint = Color(0xFFF1EBFC);
  static const chip = Color(0xFFEEF1F6);
  AppColors._();
}

class DarkColors {
  static const bg      = Color(0xFF0B1220);
  static const surface = Color(0xFF161E2E);
  static const border  = Color(0xFF283449);
  static const textPrimary   = Color(0xFFF0F3F9);
  static const textSecondary = Color(0xFF94A0B8);
  static const textTertiary  = Color(0xFF64748B);
  static const primary    = Color(0xFF5B93F5);
  static const primaryTint = Color(0xFF17233F);
  static const success    = Color(0xFF3DBB6C);
  static const successTint = Color(0xFF122A1D);
  static const danger     = Color(0xFFF0554A);
  static const dangerTint  = Color(0xFF301213);
  static const warning     = Color(0xFFE0A030);
  static const warningText  = Color(0xFFE0A030);
  static const warningTint  = Color(0xFF2E2410);
  // secondary hue — guardian role badge only, not severity
  static const accent     = Color(0xFFA284EE);
  static const accentTint  = Color(0xFF241C3D);
  static const chip = Color(0xFF212C42);
  DarkColors._();
}

class AppTheme {
  // Slide-in page transition (iOS-style, also feels native on modern Android)
  // and the M3 sparkle ripple give taps/navigation a finished, non-prototype feel.
  static const _pageTransitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  });

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        pageTransitionsTheme: _pageTransitions,
        splashFactory: InkSparkle.splashFactory,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: AppColors.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          elevation: 8,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.surface,
          titleTextStyle: TextStyle(
              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          contentTextStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        pageTransitionsTheme: _pageTransitions,
        splashFactory: InkSparkle.splashFactory,
        scaffoldBackgroundColor: DarkColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: DarkColors.primary,
          surface: DarkColors.surface,
          onSurface: DarkColors.textPrimary,
          error: DarkColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: DarkColors.surface,
          foregroundColor: DarkColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: DarkColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: DarkColors.textSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: DarkColors.surface,
          selectedItemColor: DarkColors.primary,
          unselectedItemColor: DarkColors.textTertiary,
          elevation: 8,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        cardTheme: CardThemeData(
          color: DarkColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: DarkColors.border),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: DarkColors.surface,
          titleTextStyle: const TextStyle(
              color: DarkColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          contentTextStyle: const TextStyle(color: DarkColors.textSecondary, fontSize: 14),
        ),
      );

  AppTheme._();
}

/// Layered shadow (tight contact shadow + soft ambient shadow) reads as a
/// single crisp, gently elevated surface — the standard two-layer technique
/// modern design systems use instead of one flat drop shadow.
BoxDecoration cardDeco({double radius = 16, bool dark = false, bool bordered = true}) => BoxDecoration(
      color: dark ? DarkColors.surface : AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: bordered ? Border.all(color: dark ? DarkColors.border : AppColors.border) : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.24 : 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.20 : 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );

InputDecoration lightInputDeco(String label, {IconData? icon}) =>
    appInputDeco(label, icon: icon, dark: false);

/// Theme-aware input decoration — pass `dark: true` on screens that support
/// dark mode so fields don't stay light against a dark background.
InputDecoration appInputDeco(String label, {IconData? icon, bool dark = false}) {
  final surface = dark ? DarkColors.surface : AppColors.surface;
  final border  = dark ? DarkColors.border  : AppColors.border;
  final textSec = dark ? DarkColors.textSecondary : AppColors.textSecondary;
  final textTer = dark ? DarkColors.textTertiary  : AppColors.textTertiary;
  final primary = dark ? DarkColors.primary : AppColors.primary;
  final danger  = dark ? DarkColors.danger  : AppColors.danger;
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: textSec, fontSize: 14),
    prefixIcon: icon != null ? Icon(icon, color: textTer, size: 20) : null,
    filled: true,
    fillColor: surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: danger, width: 1.5),
    ),
    errorStyle: TextStyle(color: danger),
  );
}
