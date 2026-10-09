import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/preparation_view.dart';

class ReportSaveStatus extends StatelessWidget {
  const ReportSaveStatus({super.key, required this.controller});
  final ReportController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.autosaveDelay == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.saving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Salvando alterações...'),
            ),
          if (controller.saveError != null) ...[
            Text(
              userError(controller.saveError),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (controller.conflict)
              TextButton(
                onPressed: controller.saving ? null : controller.reloadLatest,
                child: const Text('Recarregar versão mais recente'),
              )
            else
              TextButton(
                onPressed: () async {
                  try {
                    await controller.saveDraft();
                  } catch (_) {}
                },
                child: const Text('Tentar salvar novamente'),
              ),
          ],
          if (controller.preservedDraft != null && !controller.conflict)
            TextButton(
              onPressed: () async {
                final restore = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Rascunho preservado'),
                    scrollable: true,
                    content: Text(
                      [
                        controller.preservedDraft!.originalText,
                        ...controller.preservedDraft!.sections.map(
                          (s) => '${s.title}\n${s.text}',
                        ),
                        ...controller.preservedDraft!.questions.map(
                          (q) =>
                              '${q.selected ? 'Selecionada' : 'Não selecionada'}: ${q.text}',
                        ),
                      ].join('\n\n'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Fechar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Restaurar para editar'),
                      ),
                    ],
                  ),
                );
                if (restore == true) controller.restorePreservedDraft();
              },
              child: const Text('Ver rascunho preservado'),
            ),
          if (controller.hasUnsavedChanges &&
              !controller.saving &&
              !controller.conflict &&
              controller.saveError == null)
            TextButton(
              onPressed: () async {
                try {
                  await controller.saveDraft();
                } catch (_) {}
              },
              child: const Text('Salvar rascunho'),
            ),
        ],
      );
    },
  );
}

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
    this.controller,
  });
  final String title, subtitle, backTo;
  final String? eyebrow;
  final Widget? action;
  final List<Widget> children;
  final ReportController? controller;
  @override
  Widget build(BuildContext context) => controller == null
      ? _content(context)
      : PreparationView(controller: controller!.preparation, builder: _content);
  Widget _content(BuildContext context) => Scaffold(
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
            if (controller != null) ReportSaveStatus(controller: controller!),
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
    return AppDialog(
      title: widget.title,
      subtitle: question
          ? 'Revise ou edite sua pergunta para levar à consulta.'
          : 'Revise ou edite este conteúdo antes da consulta.',
      content: AppWritingField(
        fieldKey: const ValueKey('report-edit-field'),
        controller: controller,
        autofocus: true,
        minLines: question ? 2 : 4,
        maxLines: question ? 4 : 10,
        maxLength: question ? 250 : null,
        counterReference: question ? 250 : 500,
        errorText: _error,
        label: question ? 'Pergunta' : 'Conteúdo informado',
      ),
      actions: AppDialogActions(
        secondaryLabel: 'Cancelar',
        onSecondary: () => Navigator.pop(context),
        destructiveLabel: question ? null : 'Remover conteúdo',
        onDestructive: () => Navigator.pop(context, ''),
        primaryLabel: 'Salvar',
        primaryKey: const ValueKey('report-edit-save'),
        onPrimary: () {
          if (question && controller.text.trim().isEmpty) {
            setState(() => _error = 'Escreva sua pergunta.');
            return;
          }
          Navigator.pop(context, controller.text.trim());
        },
      ),
    );
  }
}
