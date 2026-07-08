import 'package:flutter/material.dart';

class AppColors {
  // Light
  static const bg = Color(0xFFFBF8F4);
  static const surface = Color(0xFFFFFEFC);
  static const border = Color(0xFFEAE5DC);
  static const textPrimary = Color(0xFF2B2A28);
  static const textSecondary = Color(0xFF6B6660);
  static const textTertiary = Color(0xFF948E85);
  static const primary = Color(0xFF6366F1);
  static const primaryPressed = Color(0xFF4F46E5);
  static const primaryTint = Color(0xFFEEF2FF);
  static const success = Color(0xFF1A9460);
  static const successTint = Color(0xFFE7F7EE);
  static const danger = Color(0xFFD94035);
  static const dangerPressed = Color(0xFFB82A21);
  static const dangerTint = Color(0xFFFDEBEA);
  static const warning = Color(0xFFEF9D2E);
  static const warningText = Color(0xFFAD6E16);
  static const warningTint = Color(0xFFFDF3E3);
  static const accent = Color(0xFFE88A30);
  static const accentTint = Color(0xFFFCEED8);
  static const chip = Color(0xFFF2EFE9);
  AppColors._();
}

class DarkColors {
  static const bg      = Color(0xFF111318);
  static const surface = Color(0xFF1C1E24);
  static const border  = Color(0xFF2E3038);
  static const textPrimary   = Color(0xFFEBEBF5);
  static const textSecondary = Color(0xFFAEAEB2);
  static const textTertiary  = Color(0xFF636366);
  static const primary    = Color(0xFF818CF8);
  static const primaryTint = Color(0xFF1E1B4B);
  static const success    = Color(0xFF30D158);
  static const successTint = Color(0xFF0D2A1A);
  static const danger     = Color(0xFFFF453A);
  static const dangerTint  = Color(0xFF2A0F0D);
  static const warning     = Color(0xFFFFD60A);
  static const warningText  = Color(0xFFFFD60A);
  static const warningTint  = Color(0xFF2A220A);
  static const accent     = Color(0xFFFF9A3C);
  static const accentTint  = Color(0xFF3A2010);
  static const chip = Color(0xFF2C2E36);
  DarkColors._();
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
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

BoxDecoration cardDeco({double radius = 16, bool dark = false}) => BoxDecoration(
      color: dark ? DarkColors.surface : AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.18 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

InputDecoration lightInputDeco(String label, {IconData? icon}) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: AppColors.textTertiary, size: 20) : null,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(color: AppColors.danger),
    );
