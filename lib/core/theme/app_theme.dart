import 'package:flutter/material.dart';

/// 다미의 크림·갈색 팔레트.
abstract final class AppColors {
  static const cream = Color(0xFFFBF3E4);
  static const paper = Color(0xFFFFFBF4);
  static const brown = Color(0xFF5B3A24);
  static const caramel = Color(0xFFC98B4E);
  static const ink = Color(0xFF3B2A1E);
  static const muted = Color(0xFF8C7462);

  /// 카메라 바디.
  static const body = Color(0xFF1E1813);

  /// 암실(현상) 톤.
  static const darkroom = Color(0xFF140504);
  static const safelight = Color(0xFFB3261E);
}

abstract final class AppTheme {
  static final light = _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.brown,
      primary: AppColors.brown,
      secondary: AppColors.caramel,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
    ),
  );

  static final dark = _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.brown,
      brightness: Brightness.dark,
      secondary: AppColors.caramel,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.brightness == Brightness.light ? AppColors.paper : null,
        elevation: 0,
        shape: shape.copyWith(
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.brightness == Brightness.light
            ? AppColors.paper
            : null,
      ),
    );
  }
}
