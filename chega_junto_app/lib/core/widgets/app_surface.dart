import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surface,
    this.border = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool border;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: border ? Border.all(color: AppColors.border) : null,
    ),
    child: child,
  );
}

class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.background = AppColors.blueSoft,
    this.size = 46,
  });
  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: Icon(icon, color: color, size: size * .56),
  );
}
