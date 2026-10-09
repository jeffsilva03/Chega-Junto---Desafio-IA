import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/organized_report.dart';
import '../../../../features/pre_visit_report/presentation/widgets/report_components.dart';

class ConsultationQuestionsPage extends StatefulWidget {
  const ConsultationQuestionsPage({
    super.key,
    required this.controller,
    this.returnToReview = false,
  });
  final ReportController controller;
  final bool returnToReview;
  @override
  State<ConsultationQuestionsPage> createState() =>
      _ConsultationQuestionsPageState();
}

class _ConsultationQuestionsPageState extends State<ConsultationQuestionsPage> {
  bool _saving = false;
  Future<void> _edit([ConsultationQuestion? question]) async {
    final value = await editReportText(
      context,
      title: question == null ? 'Minha pergunta' : 'Editar pergunta',
      value: question?.text ?? '',
      question: true,
    );
    if (value != null) widget.controller.saveQuestion(value, id: question?.id);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await widget.controller.finishReview();
      if (!mounted) return;
      setState(() => _saving = false);
      if (widget.returnToReview && context.canPop()) {
        context.pop();
      } else {
        context.push(AppRoutes.finalReview);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        reportMessage(
          context,
          userError(
            e,
            'Não foi possível salvar. Revise o resumo e tente novamente.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final allSelected =
          controller.questions.isNotEmpty &&
          controller.questions.every((q) => q.selected);
      return ReportScaffold(
        controller: controller,
        title: 'Perguntas para levar à consulta',
        eyebrow: 'PRÓXIMA CONSULTA',
        backTo: AppRoutes.summary,
        subtitle:
            'Sugestões para ajudar você a aproveitar melhor o atendimento. Escolha as que fizerem sentido para você.',
        action: IconButton(
          tooltip: 'Ajuda',
          onPressed: () => context.push(AppRoutes.help),
          icon: const Icon(Icons.help_outline_rounded),
        ),
        children: [
          if (controller.showSuggestions) ...[
            AppSurface(
              color: context.appColors.purpleSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    icon: Icons.lightbulb_outline_rounded,
                    color: context.appColors.purple,
                    background: context.appColors.purpleSoft,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Essas são sugestões',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Você pode editar, adicionar ou remover as perguntas que fizerem sentido para você.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ocultar sugestões',
                    onPressed: controller.dismissSuggestions,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Text(
                'Perguntas sugeridas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(
                onPressed: () => controller.selectAll(!allSelected),
                child: Text(
                  allSelected ? 'Desmarcar todas' : 'Selecionar todas',
                  style: TextStyle(color: context.appColors.purple),
                ),
              ),
            ],
          ),
          if (!controller.hasContent) ...[
            const Text('Revise o resumo antes de escolher suas perguntas.'),
            TextButton(
              onPressed: () => context.go(AppRoutes.summary),
              child: const Text('Voltar ao resumo'),
            ),
          ],
          for (final question in controller.questions) ...[
            AppSurface(
              border: true,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      key: ValueKey('question-${question.id}'),
                      value: question.selected,
                      onChanged: (value) => controller.selectQuestion(
                        question.id,
                        value ?? false,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.only(left: 4),
                      activeColor: context.appColors.purple,
                      checkColor: context.appColors.onPrimary,
                      title: Text(
                        question.text,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opções da pergunta',
                    icon: const Icon(Icons.drag_handle_rounded),
                    onSelected: (action) {
                      switch (action) {
                        case 'edit':
                          _edit(question);
                        case 'remove':
                          controller.removeQuestion(question.id);
                        case 'up':
                          controller.moveQuestion(question.id, -1);
                        case 'down':
                          controller.moveQuestion(question.id, 1);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar pergunta'),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remover pergunta'),
                      ),
                      if (question != controller.questions.first)
                        const PopupMenuItem(
                          value: 'up',
                          child: Text('Mover para cima'),
                        ),
                      if (question != controller.questions.last)
                        const PopupMenuItem(
                          value: 'down',
                          child: Text('Mover para baixo'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (controller.questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhuma pergunta adicionada. Você pode continuar sem perguntas.',
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _edit(),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appColors.purple,
              backgroundColor: context.appColors.purpleSoft,
              padding: const EdgeInsets.all(16),
              side: BorderSide.none,
            ),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Adicionar minha própria pergunta'),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Continuar',
            color: AppColors.purple,
            busy: _saving,
            onPressed: _finish,
          ),
        ],
      );
    },
  );
}
