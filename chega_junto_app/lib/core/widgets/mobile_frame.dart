import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFEAF4F9),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.maxWidth),
        child: child,
      ),
    ),
  );
}
