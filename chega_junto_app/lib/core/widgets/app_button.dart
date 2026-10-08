import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.outlined = false,
    this.busy = false,
    this.color = AppColors.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool busy;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final color = context.appColors.resolve(this.color);
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? color : context.appColors.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
        if (icon != null && !busy) ...[
          const SizedBox(width: 16),
          Icon(icon, size: 24),
        ],
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(double.infinity, AppLayout.controlHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge),
      backgroundColor: outlined
          ? const WidgetStatePropertyAll(Colors.transparent)
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? color.withValues(alpha: .45)
                  : color,
            ),
      foregroundColor: WidgetStatePropertyAll(
        outlined ? color : context.appColors.onPrimary,
      ),
      side: outlined ? WidgetStatePropertyAll(BorderSide(color: color)) : null,
      elevation: const WidgetStatePropertyAll(0),
    );
    return outlined
        ? OutlinedButton(
            onPressed: busy ? null : onPressed,
            style: style,
            child: content,
          )
        : FilledButton(
            onPressed: busy ? null : onPressed,
            style: style,
            child: content,
          );
  }
}
