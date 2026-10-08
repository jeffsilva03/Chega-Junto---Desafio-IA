import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.icon,
    this.color = AppColors.tealDark,
  });
  final String title;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, color: context.appColors.resolve(color), size: 25),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
    ],
  );
}
