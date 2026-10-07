import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_surface.dart';

class ProfileMenuGroup extends StatelessWidget {
  const ProfileMenuGroup({
    super.key,
    required this.title,
    required this.items,
    required this.onSelect,
  });
  final String title;
  final List<(IconData, String)> items;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      AppSurface(
        border: true,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final entry in items.indexed) ...[
              if (entry.$1 > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 48, right: 12),
                  child: Divider(),
                ),
              InkWell(
                onTap: () => onSelect(entry.$2.$2),
                borderRadius: BorderRadius.circular(AppRadii.large),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (entry.$2.$1 == Icons.medication_outlined)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CustomPaint(painter: _CapsulePainter()),
                        )
                      else
                        Icon(entry.$2.$1, color: AppColors.primary, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.$2.$2,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class _CapsulePainter extends CustomPainter {
  const _CapsulePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(.785398);
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-5.5, -11, 11, 22),
        const Radius.circular(5.5),
      ),
      paint,
    );
    canvas.drawLine(const Offset(-5.5, 0), const Offset(5.5, 0), paint);
  }

  @override
  bool shouldRepaint(_CapsulePainter oldDelegate) => false;
}
