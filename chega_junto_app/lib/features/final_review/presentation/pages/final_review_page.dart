import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/utils/appointment_date.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../../../../data/models/checklist_item.dart';
import '../../../pre_visit_report/presentation/widgets/report_components.dart';
import '../widgets/review_section.dart';

class FinalReviewPage extends StatefulWidget {
  const FinalReviewPage({super.key, required this.controller});
  final ReportController controller;

  @override
  State<FinalReviewPage> createState() => _FinalReviewPageState();
}

class _FinalReviewPageState extends State<FinalReviewPage> {
  bool _saving = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await widget.controller.completePreparation();
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (_) {
      if (mounted) {
        reportMessage(
          context,
          'Não foi possível concluir. Revise o resumo atualizado e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _editButton(
    String label,
    IconData icon,
    VoidCallback action,
    String key,
  ) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: ValueKey(key),
      onPressed: _saving ? null : action,
      style: TextButton.styleFrom(
        backgroundColor: context.appColors.blueSoft,
        foregroundColor: context.appColors.primary,
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) => PreparationView(
    controller: widget.controller.preparation,
    builder: (context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final overview = controller.preparation.overview!;
        final appointment = overview.nextAppointment;
        final complete = controller.preparation.finalReviewCompleted;
        final allComplete = overview.progress.fraction == 1;
        final selected = controller.selectedQuestions;
        final summary = controller.sections
            .where((section) => section.text.trim().isNotEmpty)
            .toList();
        return Scaffold(
          backgroundColor: context.appColors.surface,
          bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Voltar',
                      onPressed: () => reportBack(context, AppRoutes.questions),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: complete
                              ? context.appColors.tealSoft
                              : context.appColors.blueSoft,
                        ),
                        child: Icon(
                          complete
                              ? Icons.check_rounded
                              : Icons.fact_check_outlined,
                          color: complete
                              ? context.appColors.tealDark
                              : context.appColors.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              liveRegion: true,
                              header: true,
                              child: Text(
                                allComplete
                                    ? 'Preparação concluída'
                                    : complete
                                    ? 'Revisão final concluída'
                                    : 'Preparar para a consulta',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Confira seus dados abaixo. Você pode revisar e editar antes da consulta.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: context.appColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${overview.progress.completedCount} de ${overview.progress.totalCount} etapas • ${overview.progress.percentage}%',
                    key: const ValueKey('final-review-progress'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ReviewSection(
                    key: const ValueKey('review-appointment'),
                    title: 'Consulta',
                    subtitle:
                        '${AppointmentDate.fullDate(appointment.dateTime)} • ${AppointmentDate.time(appointment.dateTime)}\n${appointment.facilityName}',
                    icon: Icons.calendar_month_rounded,
                    children: [
                      Text(
                        appointment.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(appointment.specialty),
                      Text(appointment.professionalName),
                      const SizedBox(height: 6),
                      Text(
                        appointment.address,
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ReviewSection(
                    key: const ValueKey('review-summary'),
                    title: 'Seu relato',
                    subtitle:
                        'Revise o resumo do seu relato para esta consulta.',
                    icon: Icons.description_outlined,
                    teal: true,
                    initiallyExpanded: true,
                    children: [
                      AppSurface(
                        color: context.appColors.background,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (summary.isEmpty)
                              const Text(
                                'Você ainda não tem um resumo revisado. Organize seu relato para continuar.',
                              ),
                            if (controller.summaryOutdated)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Seu relato mudou. Organize a versão atual antes de concluir.',
                                ),
                              ),
                            for (final entry in summary.indexed) ...[
                              if (entry.$1 > 0) const SizedBox(height: 10),
                              Text(
                                entry.$2.text,
                                key: ValueKey('review-summary-${entry.$2.id}'),
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: context.appColors.textSecondary,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _editButton(
                              summary.isEmpty
                                  ? 'Preparar relato'
                                  : 'Editar resumo',
                              Icons.edit_outlined,
                              () => context.push(
                                summary.isEmpty || controller.summaryOutdated
                                    ? AppRoutes.report
                                    : AppRoutes.summary,
                              ),
                              'review-edit-summary',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ReviewSection(
                    key: const ValueKey('review-questions'),
                    title: 'Perguntas que você escolheu',
                    subtitle: 'Revise as perguntas que deseja levar.',
                    icon: Icons.help_outline_rounded,
                    initiallyExpanded: true,
                    children: [
                      AppSurface(
                        color: context.appColors.background,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (selected.isEmpty)
                              const Text(
                                'Nenhuma pergunta selecionada. Você pode concluir sem perguntas.',
                              ),
                            for (final question in selected)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 22,
                                      color: context.appColors.tealDark,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        question.text,
                                        key: ValueKey(
                                          'review-question-${question.id}',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: context
                                                  .appColors
                                                  .textSecondary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            _editButton(
                              'Editar perguntas',
                              Icons.edit_outlined,
                              () => context.push(
                                '${AppRoutes.questions}?from=review',
                              ),
                              'review-edit-questions',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ReviewSection(
                    key: const ValueKey('review-documents'),
                    title: 'Documentos para levar (opcional)',
                    subtitle: 'Confira os documentos no seu checklist.',
                    icon: Icons.description_outlined,
                    children: [
                      for (final item in overview.checklist.where(
                        (item) => item.section == ChecklistSection.documents,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${item.title} — ${item.isCompleted ? 'conferido' : 'pendente'}',
                          ),
                        ),
                      _editButton(
                        'Revisar checklist',
                        Icons.checklist_rounded,
                        () => context.push(AppRoutes.checklist),
                        'review-edit-checklist',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Você decide o que compartilhar. Concluir salva sua preparação somente nesta sessão; nada é enviado a profissionais, UBS ou SUS.',
                    key: const ValueKey('review-privacy'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: complete
                        ? 'Voltar ao início'
                        : 'Concluir preparação',
                    color: AppColors.tealDark,
                    busy: _saving,
                    onPressed: complete
                        ? () => context.go(AppRoutes.home)
                        : controller.hasContent && !controller.summaryOutdated
                        ? _finish
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
