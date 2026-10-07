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
}

abstract final class AppLayout {
  static const maxWidth = 430.0;
  static const controlHeight = 48.0;
}
