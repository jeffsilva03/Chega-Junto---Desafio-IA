import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';

/// Shared presentation for the approved writing and help cards.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.subtitle,
    this.roundClose = false,
  });
  final String title;
  final String? subtitle;
  final Widget content, actions;
  final bool roundClose;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.appColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(AppSpacing.page),
    constraints: const BoxConstraints(maxWidth: AppLayout.dialogMaxWidth),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.dialog),
      side: context.appColors.highContrast
          ? BorderSide(color: context.appColors.border)
          : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final body = Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Semantics(
                        namesRoute: true,
                        header: true,
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'Fechar janela',
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: context.appColors.blueSoft,
                      foregroundColor: context.appColors.ink,
                      minimumSize: const Size.square(48),
                      shape: roundClose
                          ? const CircleBorder()
                          : RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.medium,
                              ),
                            ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              content,
            ],
          ),
        );
        final footer = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: actions,
            ),
          ],
        );
        // On very short viewports the entire card can scroll, including actions.
        // Otherwise only its content scrolls and the actions remain visible.
        final short =
            constraints.maxHeight <
            160 * MediaQuery.textScalerOf(context).scale(1);
        return SizedBox(
          width: AppLayout.dialogMaxWidth,
          child: short
              ? SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [body, footer],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: SingleChildScrollView(child: body)),
                    footer,
                  ],
                ),
        );
      },
    ),
  );
}

class AppDialogActions extends StatelessWidget {
  const AppDialogActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.primaryKey,
    this.destructiveLabel,
    this.onDestructive,
    this.secondaryOutlined = true,
  });
  final String primaryLabel, secondaryLabel;
  final String? destructiveLabel;
  final VoidCallback onPrimary, onSecondary;
  final VoidCallback? onDestructive;
  final Key? primaryKey;
  final bool secondaryOutlined;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(
        context,
      ).textTheme.labelLarge!.copyWith(fontSize: 14);
      final scaler = MediaQuery.textScalerOf(context);
      double width(String text) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout();
        return (painter.width + 16).clamp(48, double.infinity);
      }

      final buttonStyle = FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        textStyle: style,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      );
      final primary = FilledButton(
        key: primaryKey,
        onPressed: onPrimary,
        style: buttonStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(context.appColors.primary),
          foregroundColor: WidgetStatePropertyAll(context.appColors.onPrimary),
        ),
        child: Text(primaryLabel, textAlign: TextAlign.center),
      );
      final secondaryStyle = buttonStyle.copyWith(
        foregroundColor: WidgetStatePropertyAll(context.appColors.primary),
        side: WidgetStatePropertyAll(
          secondaryOutlined
              ? BorderSide(color: context.appColors.primary)
              : BorderSide.none,
        ),
      );
      final secondary = secondaryOutlined
          ? OutlinedButton(
              onPressed: onSecondary,
              style: secondaryStyle,
              child: Text(secondaryLabel, textAlign: TextAlign.center),
            )
          : TextButton(
              onPressed: onSecondary,
              style: secondaryStyle,
              child: Text(secondaryLabel, textAlign: TextAlign.center),
            );
      final destructive = destructiveLabel == null
          ? null
          : TextButton(
              onPressed: onDestructive,
              style: TextButton.styleFrom(
                foregroundColor: context.appColors.error,
                textStyle: style,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(child: Text(destructiveLabel!)),
                ],
              ),
            );
      final pairWidth = width(primaryLabel) + width(secondaryLabel) + 8;
      if (destructive != null &&
          pairWidth + width(destructiveLabel!) + 16 <= constraints.maxWidth) {
        return Row(
          children: [
            destructive,
            const Spacer(),
            secondary,
            const SizedBox(width: 8),
            primary,
          ],
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (destructive != null) ...[
            Align(alignment: Alignment.centerLeft, child: destructive),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (pairWidth <= constraints.maxWidth)
            Row(
              children: [
                Expanded(child: secondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: primary),
              ],
            )
          else ...[
            secondary,
            const SizedBox(height: AppSpacing.sm),
            primary,
          ],
        ],
      );
    },
  );
}

/// A labeled writing area with the counter inside the field, as in the reference.
/// [counterReference] is informative; only [maxLength] limits input.
class AppWritingField extends StatefulWidget {
  const AppWritingField({
    super.key,
    required this.controller,
    required this.label,
    this.fieldKey,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.counterReference,
    this.autofocus = false,
    this.keyboardType,
    this.validator,
    this.errorText,
  });
  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final int minLines, maxLines;
  final int? maxLength, counterReference;
  final bool autofocus;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final String? errorText;

  @override
  State<AppWritingField> createState() => _AppWritingFieldState();
}

class _AppWritingFieldState extends State<AppWritingField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormField<String>(
    initialValue: widget.controller.text,
    validator: widget.validator,
    builder: (field) => ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _focus]),
      builder: (context, _) {
        final limit = widget.counterReference ?? widget.maxLength;
        return InputDecorator(
          isFocused: _focus.hasFocus,
          isEmpty: widget.controller.text.isEmpty,
          decoration: InputDecoration(
            labelText: widget.label,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            alignLabelWithHint: true,
            fillColor: context.appColors.background,
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            errorText: widget.errorText ?? field.errorText,
            errorMaxLines: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: widget.fieldKey,
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                keyboardType: widget.keyboardType,
                onChanged: field.didChange,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      required maxLength,
                    }) => null,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
              ),
              if (limit != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${widget.controller.text.characters.length}/$limit',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
