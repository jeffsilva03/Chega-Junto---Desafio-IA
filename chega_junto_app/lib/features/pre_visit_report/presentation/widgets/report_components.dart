import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';

void reportMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

void reportBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

class ReportScaffold extends StatelessWidget {
  const ReportScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.eyebrow,
    this.action,
    this.backTo = AppRoutes.report,
  });
  final String title, subtitle, backTo;
  final String? eyebrow;
  final Widget? action;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.surface,
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Voltar',
                  onPressed: () => reportBack(context, backTo),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) ...[
                          Text(
                            eyebrow!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    ),
  );
}

Future<String?> editReportText(
  BuildContext context, {
  required String title,
  required String value,
  bool question = false,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _ReportTextDialog(title: title, value: value, question: question),
);

class _ReportTextDialog extends StatefulWidget {
  const _ReportTextDialog({
    required this.title,
    required this.value,
    required this.question,
  });
  final String title, value;
  final bool question;
  @override
  State<_ReportTextDialog> createState() => _ReportTextDialogState();
}

class _ReportTextDialogState extends State<_ReportTextDialog> {
  late final controller = TextEditingController(text: widget.value);
  String? _error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: TextField(
        key: const ValueKey('report-edit-field'),
        controller: controller,
        autofocus: true,
        minLines: question ? 2 : 4,
        maxLines: question ? 4 : 10,
        maxLength: question ? 250 : null,
        decoration: InputDecoration(
          errorText: _error,
          labelText: question ? 'Pergunta' : 'Conteúdo informado',
          alignLabelWithHint: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        if (!question)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Remover conteúdo'),
          ),
        TextButton(
          key: const ValueKey('report-edit-save'),
          onPressed: () {
            if (question && controller.text.trim().isEmpty) {
              setState(() => _error = 'Escreva sua pergunta.');
              return;
            }
            Navigator.pop(context, controller.text.trim());
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
