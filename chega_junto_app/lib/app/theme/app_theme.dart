import 'package:flutter/material.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light {
    const base = TextStyle(
      fontFamily: 'NunitoSans',
      color: AppColors.ink,
      height: 1.35,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.teal,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: 'NunitoSans',
      textTheme: TextTheme(
        headlineLarge: base.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -.7,
        ),
        headlineMedium: base.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          height: 1.2,
          letterSpacing: -.4,
        ),
        titleLarge: base.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
        ),
        titleMedium: base.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
        bodyLarge: base.copyWith(fontSize: 16),
        bodyMedium: base.copyWith(fontSize: 14),
        bodySmall: base.copyWith(fontSize: 12, color: AppColors.textSecondary),
        labelLarge: base.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
        labelMedium: base.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: base.copyWith(color: AppColors.muted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorMaxLines: 2,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: base.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
