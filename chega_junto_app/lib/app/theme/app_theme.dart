import 'package:flutter/material.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light => create();
  static ThemeData create({
    bool dark = false,
    bool highContrast = false,
    bool reduceMotion = false,
  }) {
    final colors = AppPalette(dark: dark, highContrast: highContrast);
    final base = TextStyle(
      fontFamily: 'NunitoSans',
      color: colors.ink,
      height: 1.35,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      extensions: [colors],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AccessibleTransitions(),
          TargetPlatform.iOS: _AccessibleTransitions(),
          TargetPlatform.windows: _AccessibleTransitions(),
          TargetPlatform.macOS: _AccessibleTransitions(),
          TargetPlatform.linux: _AccessibleTransitions(),
        },
      ),
      splashFactory: reduceMotion
          ? NoSplash.splashFactory
          : InkRipple.splashFactory,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        secondary: colors.teal,
        surface: colors.surface,
        onSurface: colors.ink,
        error: colors.error,
      ),
      scaffoldBackgroundColor: colors.surface,
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
        bodySmall: base.copyWith(fontSize: 12, color: colors.textSecondary),
        labelLarge: base.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
        labelMedium: base.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: base.copyWith(color: colors.muted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorMaxLines: 2,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: base.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 24),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _AccessibleTransitions extends PageTransitionsBuilder {
  const _AccessibleTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : const FadeUpwardsPageTransitionsBuilder().buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}
