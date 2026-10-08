import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0064FF);
  static const primaryDark = Color(0xFF075BB8);
  static const ink = Color(0xFF071C47);
  static const textSecondary = Color(0xFF536C96);
  static const muted = Color(0xFF5E718F);
  static const surface = Colors.white;
  static const background = Color(0xFFF5FAFE);
  static const border = Color(0xFFE0E8F2);
  static const blueSoft = Color(0xFFEAF4FF);
  static const teal = Color(0xFF19BE9B);
  static const tealDark = Color(0xFF008571);
  static const tealSoft = Color(0xFFE2FAF2);
  static const warning = Color(0xFFF5A000);
  static const warningSoft = Color(0xFFFFF3DF);
  static const purple = Color(0xFF7355C8);
  static const purpleSoft = Color(0xFFF0EBFC);
  static const error = Color(0xFFBC3240);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const page = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
}

abstract final class AppRadii {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const sheet = 24.0;
  static const dialog = 20.0;
}

abstract final class AppLayout {
  static const maxWidth = 430.0;
  static const controlHeight = 48.0;
  static const dialogMaxWidth = 400.0;
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({this.dark = false, this.highContrast = false});
  final bool dark, highContrast;
  Color resolve(Color color) {
    const keys = [
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.ink,
      AppColors.textSecondary,
      AppColors.muted,
      AppColors.surface,
      AppColors.background,
      AppColors.border,
      AppColors.blueSoft,
      AppColors.teal,
      AppColors.tealDark,
      AppColors.tealSoft,
      AppColors.warning,
      AppColors.warningSoft,
      AppColors.purple,
      AppColors.purpleSoft,
      AppColors.error,
    ];
    const darkValues = [
      Color(0xFF84B6FF),
      Color(0xFFA6CAFF),
      Color(0xFFEAF1FF),
      Color(0xFFB7C8E4),
      Color(0xFFB7C8E4),
      Color(0xFF14243B),
      Color(0xFF0B1628),
      Color(0xFF3E5470),
      Color(0xFF1D3554),
      Color(0xFF53DDBE),
      Color(0xFF80E8D3),
      Color(0xFF173F39),
      Color(0xFFFFC875),
      Color(0xFF43351F),
      Color(0xFFCBB6FF),
      Color(0xFF35294E),
      Color(0xFFFFA5AF),
    ];
    final index = keys.indexOf(color);
    var result = dark && index >= 0 ? darkValues[index] : color;
    if (highContrast) {
      if (color == AppColors.ink) result = dark ? Colors.white : Colors.black;
      if (color == AppColors.textSecondary || color == AppColors.muted) {
        result = dark ? const Color(0xFFF0F4FF) : const Color(0xFF23344B);
      }
      if (color == AppColors.border) {
        result = dark ? const Color(0xFF9EAFC8) : const Color(0xFF53647D);
      }
      if (color == AppColors.primary || color == AppColors.primaryDark) {
        result = dark ? const Color(0xFFB9D5FF) : const Color(0xFF004BBF);
      }
      if (color == AppColors.tealDark) {
        result = dark ? const Color(0xFFB7FFEA) : const Color(0xFF005A4C);
      }
      if (color == AppColors.purple) {
        result = dark ? const Color(0xFFE7DBFF) : const Color(0xFF4D2C91);
      }
      if (color == AppColors.error) {
        result = dark ? const Color(0xFFFFD2D7) : const Color(0xFF8F1523);
      }
    }
    return result;
  }

  Color get primary => resolve(AppColors.primary);
  Color get primaryDark => resolve(AppColors.primaryDark);
  Color get ink => resolve(AppColors.ink);
  Color get textSecondary => resolve(AppColors.textSecondary);
  Color get muted => resolve(AppColors.muted);
  Color get surface => resolve(AppColors.surface);
  Color get background => resolve(AppColors.background);
  Color get border => resolve(AppColors.border);
  Color get blueSoft => resolve(AppColors.blueSoft);
  Color get teal => resolve(AppColors.teal);
  Color get tealDark => resolve(AppColors.tealDark);
  Color get tealSoft => resolve(AppColors.tealSoft);
  Color get warning => resolve(AppColors.warning);
  Color get warningSoft => resolve(AppColors.warningSoft);
  Color get purple => resolve(AppColors.purple);
  Color get purpleSoft => resolve(AppColors.purpleSoft);
  Color get error => resolve(AppColors.error);
  Color get onPrimary => dark ? AppColors.ink : Colors.white;
  @override
  AppPalette copyWith({bool? dark, bool? highContrast}) => AppPalette(
    dark: dark ?? this.dark,
    highContrast: highContrast ?? this.highContrast,
  );
  @override
  AppPalette lerp(covariant AppPalette? other, double t) =>
      t < .5 ? this : other ?? this;
}

extension AppPaletteContext on BuildContext {
  AppPalette get appColors =>
      Theme.of(this).extension<AppPalette>() ?? const AppPalette();
}
