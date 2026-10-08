import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';
import 'medication_icon.dart';

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
      color: context.appColors.resolve(color),
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: border ? Border.all(color: context.appColors.border) : null,
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
      color: context.appColors.resolve(background),
      borderRadius: BorderRadius.circular(AppRadii.medium),
    ),
    child: icon == Icons.medication_outlined
        ? Center(
            child: MedicationIcon(
              color: context.appColors.resolve(color),
              size: size * .56,
            ),
          )
        : Icon(icon, color: context.appColors.resolve(color), size: size * .56),
  );
}
