import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

class MobileFrame extends StatelessWidget {
  const MobileFrame({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.maxWidth,
  });
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.appColors.dark
        ? context.appColors.background
        : const Color(0xFFEAF4F9),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}
