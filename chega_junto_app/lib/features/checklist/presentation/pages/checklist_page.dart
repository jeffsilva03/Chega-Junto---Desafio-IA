import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/appointment_summary_card.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../../../../core/widgets/section_heading.dart';
import '../../../../data/models/checklist_item.dart';

class ChecklistPage extends StatelessWidget {
  const ChecklistPage({super.key, required this.controller});
  final PreparationController controller;

  Future<void> _toggle(BuildContext context, ChecklistItem item) async {
    try {
      await controller.setChecklistItem(item.id, !item.isCompleted);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userError(
                e,
                'Não foi possível atualizar o item. Tente novamente.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
      backgroundColor: context.appColors.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Checklist de preparo',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      leading: IconButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: SafeArea(
      top: false,
      child: PreparationView(
        controller: controller,
        builder: (context) {
          final overview = controller.overview!;
          final fraction =
              overview.checklistFraction ??
              requiredChecklistProgress(overview.checklist);
          final percentage = (fraction * 100).round();
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppointmentSummaryCard(
                    appointment: overview.nextAppointment,
                    compact: true,
                  ),
                  const SizedBox(height: 12),
                  AppSurface(
                    border: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: percentage == 100
                                    ? context.appColors.tealSoft
                                    : context.appColors.warningSoft,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    percentage == 100
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.schedule_rounded,
                                    size: 18,
                                    color: percentage == 100
                                        ? context.appColors.tealDark
                                        : context.appColors.warning,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    percentage == 100
                                        ? 'Tudo pronto'
                                        : 'Quase pronto',
                                    style: TextStyle(
                                      color: percentage == 100
                                          ? context.appColors.tealDark
                                          : context.appColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$percentage% concluído',
                              key: const Key('checklist-percentage'),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.appColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 8,
                            color: context.appColors.primary,
                            backgroundColor: context.appColors.border,
                            semanticsLabel: 'Itens obrigatórios concluídos',
                            semanticsValue: '$percentage',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Percentual dos itens obrigatórios.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final section in [
                    (ChecklistSection.documents, 'O que levar'),
                    (ChecklistSection.reminders, 'O que lembrar'),
                    (
                      ChecklistSection.conversation,
                      'Para conversar com o profissional',
                    ),
                  ]) ...[
                    SectionHeading(title: section.$2),
                    const SizedBox(height: 10),
                    AppSurface(
                      border: true,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          if (section.$1 == ChecklistSection.reminders &&
                              overview.nextAppointment.instructions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.appColors.blueSoft,
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.small,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: context.appColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        overview
                                            .nextAppointment
                                            .instructions
                                            .last,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
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
                            ),
                          ...overview.checklist
                              .where((item) => item.section == section.$1)
                              .toList()
                              .indexed
                              .map(
                                (entry) => Column(
                                  children: [
                                    if (entry.$1 > 0)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Divider(),
                                      ),
                                    _ChecklistRow(
                                      item: entry.$2,
                                      enabled: !controller.saving,
                                      onTap: () => _toggle(context, entry.$2),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  AppSurface(
                    color: context.appColors.dark
                        ? context.appColors.background
                        : const Color(0xFFF0F4F9),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Você pode editar este checklist a qualquer momento. Itens opcionais não alteram o percentual.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.appColors.textSecondary,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Concluir checklist',
                    onPressed: () {
                      context.go(AppRoutes.home);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Checklist salvo nesta demonstração.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'Preparar para compartilhar',
                    icon: Icons.edit_note_rounded,
                    outlined: true,
                    onPressed: () => context.push(AppRoutes.report),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    required this.enabled,
    required this.onTap,
  });
  final ChecklistItem item;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: item.title,
    checked: item.isCompleted,
    enabled: enabled,
    button: true,
    excludeSemantics: true,
    child: InkWell(
      key: Key('checklist-${item.id}'),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(
              item.isCompleted
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: item.isCompleted
                  ? context.appColors.primary
                  : context.appColors.textSecondary,
              size: 25,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.isRequired ? 'Obrigatório' : 'Opcional',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    ),
  );
}
