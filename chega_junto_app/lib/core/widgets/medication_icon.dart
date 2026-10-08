import 'package:flutter/material.dart';

class MedicationIcon extends StatelessWidget {
  const MedicationIcon({super.key, required this.color, this.size = 24});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CapsulePainter(color)),
  );
}

class _CapsulePainter extends CustomPainter {
  const _CapsulePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 24);
    canvas.rotate(.785398);
    final paint = Paint()
      ..color = color
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
  bool shouldRepaint(_CapsulePainter oldDelegate) => color != oldDelegate.color;
}
