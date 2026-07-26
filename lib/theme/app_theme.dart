import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF5F5F2);
  static const surfaceSoft = Color(0xFFEFEFEB);
  static const ink = Color(0xFF171714);
  static const muted = Color(0xFF77776F);
  static const line = Color(0xFFE5E5DF);
  static const positive = Color(0xFF1F6F5F);
  static const positiveSoft = Color(0xFFE4F1ED);
  static const negative = Color(0xFFA54A42);
  static const negativeSoft = Color(0xFFF7E9E7);
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.positive,
        brightness: Brightness.light,
        surface: Colors.white,
      ).copyWith(
        primary: AppColors.ink,
        secondary: AppColors.positive,
        error: AppColors.negative,
        outline: AppColors.line,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        height: 1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.8,
        color: AppColors.ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 30,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: AppColors.ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: AppColors.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.positive, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: AppColors.line),
        foregroundColor: AppColors.ink,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.ink,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.background,
      modalBackgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
