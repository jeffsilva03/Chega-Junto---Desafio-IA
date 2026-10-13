import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../widgets/summary_section_card.dart';
import '../../../../features/pre_visit_report/presentation/widgets/report_components.dart';

class AiSummaryPage extends StatelessWidget {
  const AiSummaryPage({super.key, required this.controller});
  final ReportController controller;
  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover o conteúdo do resumo?'),
        content: const Text(
          'As informações do resumo e as perguntas serão removidas. Seu relato original continuará disponível para edição.',
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
    if (confirmed == true && context.mounted) {
      controller.clearSummary();
      try {
        await controller.saveDraft();
      } catch (e) {
        if (context.mounted) reportMessage(context, userError(e));
        return;
      }
      if (!context.mounted) return;
      reportMessage(
        context,
        'Conteúdo do resumo removido. Seu relato original foi mantido.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ReportScaffold(
      controller: controller,
      title: 'Resumo gerado pela IA',
      subtitle:
          'Aqui está a organização do que você contou. Você pode revisar e editar antes da consulta.',
      action: PopupMenuButton<String>(
        tooltip: 'Opções do resumo',
        onSelected: (_) => _clear(context),
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'clear',
            child: Text('Remover conteúdo do resumo'),
          ),
        ],
      ),
      children: [
        AppSurface(
          color: context.appColors.purpleSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notes_rounded, color: context.appColors.purple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seu relato organizado',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Beta',
                    style: TextStyle(
                      color: context.appColors.purple,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'A IA ajuda a organizar o que você contou. Ela não faz diagnóstico nem substitui um profissional de saúde.',
              ),
              const SizedBox(height: 6),
              Text(
                controller.realAudio
                    ? 'Este resumo foi organizado por IA. Revise e edite antes de continuar.'
                    : 'Nesta demonstração, a organização é simulada.',
                style: TextStyle(color: context.appColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!controller.hasSummary) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Escreva ou revise seu relato para criar um resumo.'),
          ),
          AppButton(
            label: 'Escrever meu relato',
            onPressed: () => context.push(AppRoutes.report),
          ),
        ] else ...[
          if (controller.summaryOutdated) ...[
            AppSurface(
              color: context.appColors.warningSoft,
              child: const Text(
                'Seu relato foi alterado. Volte ao texto para organizar a versão atual antes de continuar.',
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.report),
              child: const Text('Revisar relato atualizado'),
            ),
          ],
          for (final entry in controller.sections.indexed) ...[
            SummarySectionCard(
              section: entry.$2,
              index: entry.$1,
              onEdited: (value) => controller.editSection(entry.$2.id, value),
            ),
            const SizedBox(height: 12),
          ],
          if (!controller.hasContent)
            TextButton(
              onPressed: () => context.push(AppRoutes.processing),
              child: const Text('Organizar novamente a partir do relato'),
            ),
          AppButton(
            label: 'Continuar para a consulta',
            color: AppColors.purple,
            onPressed: () {
              if (!controller.hasContent) {
                reportMessage(
                  context,
                  'Adicione ao menos uma informação ao resumo para continuar.',
                );
                return;
              }
              if (controller.summaryOutdated) {
                reportMessage(
                  context,
                  'Organize o relato atualizado antes de continuar.',
                );
                return;
              }
              context.push(AppRoutes.questions);
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push(AppRoutes.report),
            child: const Text('Continuar editando meu relato'),
          ),
        ],
      ],
    ),
  );
}
