import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_surface.dart';

class QuickAccessTile extends StatelessWidget {
  const QuickAccessTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
    this.background = AppColors.blueSoft,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: AppSurface(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 135 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.15;
            final iconWidget = IconTile(
              icon: icon,
              size: 36,
              color: color,
              background: background,
            );
            final text = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      iconWidget,
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                  const SizedBox(height: 9),
                  text,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconWidget,
                const SizedBox(width: 10),
                Expanded(child: text),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            );
          },
        ),
      ),
    ),
  );
}
