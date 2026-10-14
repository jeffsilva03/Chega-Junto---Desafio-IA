import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/organized_report.dart';
import 'report_components.dart';

class OrganizedReportCard extends StatelessWidget {
  const OrganizedReportCard({
    super.key,
    required this.controller,
    this.readOnly = false,
    this.onEdit,
  });
  final ReportController controller;
  final bool readOnly;
  final VoidCallback? onEdit;
  Future<void> edit(BuildContext context, ReportSection section) async {
    final value = await editReportText(
      context,
      title: section.title,
      value: section.text,
    );
    if (value != null) controller.editSection(section.id, value);
  }

  Future<void> clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover o conteúdo do resumo?'),
        content: const Text(
          'O resumo e as perguntas serão removidos. Seu relato e o complemento continuarão disponíveis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    controller.clearSummary();
    try {
      await controller.saveDraft();
    } catch (_) {
      if (context.mounted) {
        reportMessage(
          context,
          'Não foi possível salvar agora. Seu relato foi preservado.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppSurface(
    border: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.description_outlined, color: context.appColors.tealDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                readOnly ? 'Resumo do seu relato' : 'Seu relato organizado',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (readOnly)
              TextButton(onPressed: onEdit, child: const Text('Editar')),
            if (!readOnly)
              PopupMenuButton<String>(
                tooltip: 'Opções do resumo',
                onSelected: (_) => clear(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Text('Remover conteúdo do resumo'),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final section in controller.sections) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  section.title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (!readOnly)
                IconButton(
                  key: ValueKey('edit-${section.id}'),
                  tooltip: 'Editar ${section.title}',
                  onPressed: () => edit(context, section),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 19,
                    color: context.appColors.primary,
                  ),
                ),
            ],
          ),
          Text(
            section.text.trim().isEmpty
                ? 'Nenhuma informação adicionada.'
                : section.text,
            style: TextStyle(
              color: section.text.trim().isEmpty
                  ? context.appColors.textSecondary
                  : context.appColors.ink,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class ConsultationQuestionsCard extends StatelessWidget {
  const ConsultationQuestionsCard({super.key, required this.controller});
  final ReportController controller;
  Future<void> edit(
    BuildContext context, [
    ConsultationQuestion? question,
  ]) async {
    final value = await editReportText(
      context,
      title: question == null ? 'Minha pergunta' : 'Editar pergunta',
      value: question?.text ?? '',
      question: true,
    );
    if (value != null) controller.saveQuestion(value, id: question?.id);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Perguntas sugeridas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextButton.icon(
            key: const ValueKey('v9-question-add'),
            onPressed: () => edit(context),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Adicionar'),
          ),
        ],
      ),
      const Text(
        'Perguntas para levar à consulta. Elas não são respondidas no aplicativo.',
      ),
      const SizedBox(height: 12),
      for (final question in controller.questions)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CheckboxListTile(
                key: ValueKey('question-${question.id}'),
                value: question.selected,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: context.appColors.tealDark,
                title: Text(question.text),
                onChanged: (selected) =>
                    controller.selectQuestion(question.id, selected ?? false),
              ),
            ),
            PopupMenuButton<String>(
              key: ValueKey('v9-question-actions-${question.id}'),
              tooltip: 'Opções da pergunta',
              icon: Icon(
                Icons.edit_outlined,
                color: context.appColors.primary,
                size: 20,
              ),
              onSelected: (action) {
                if (action == 'edit') {
                  edit(context, question);
                } else {
                  controller.removeQuestion(question.id);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'remove', child: Text('Remover')),
              ],
            ),
          ],
        ),
      if (controller.questions.isEmpty)
        const Text('Você pode adicionar uma pergunta com suas palavras.'),
    ],
  );
}

class SelectedQuestionsReview extends StatelessWidget {
  const SelectedQuestionsReview({
    super.key,
    required this.controller,
    required this.onEdit,
  });
  final ReportController controller;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => AppSurface(
    border: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, color: context.appColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Perguntas que você escolheu (${controller.selectedQuestions.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(onPressed: onEdit, child: const Text('Editar')),
          ],
        ),
        for (final question in controller.selectedQuestions)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: context.appColors.tealDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(question.text)),
              ],
            ),
          ),
        if (controller.selectedQuestions.isEmpty)
          const Text(
            'Nenhuma pergunta selecionada. Você pode continuar assim ou escolher alguma.',
          ),
      ],
    ),
  );
}
