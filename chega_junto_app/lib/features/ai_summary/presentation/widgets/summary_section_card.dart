import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/organized_report.dart';
import '../../../../features/pre_visit_report/presentation/widgets/report_components.dart';

class SummarySectionCard extends StatelessWidget {
  const SummarySectionCard({
    super.key,
    required this.section,
    required this.index,
    required this.onEdited,
  });
  final ReportSection section;
  final int index;
  final ValueChanged<String> onEdited;
  @override
  Widget build(BuildContext context) {
    final edit = OutlinedButton.icon(
      key: ValueKey('edit-${section.id}'),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Editar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.appColors.ink,
        side: BorderSide(color: context.appColors.border),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        textStyle: Theme.of(context).textTheme.bodyMedium,
      ),
      onPressed: () async {
        final value = await editReportText(
          context,
          title: section.title,
          value: section.text,
        );
        if (value != null) onEdited(value);
      },
    );
    return AppSurface(
      border: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconTile(
                    icon: [
                      Icons.description_outlined,
                      Icons.format_list_bulleted_rounded,
                      Icons.schedule_rounded,
                      Icons.chat_bubble_outline_rounded,
                    ][index % 4],
                    color: index == 1
                        ? context.appColors.purple
                        : context.appColors.primary,
                    background: index == 1
                        ? context.appColors.purpleSoft
                        : context.appColors.blueSoft,
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (inline) ...[const SizedBox(width: 8), edit],
                ],
              ),
              const SizedBox(height: 12),
              Text(
                section.text.isEmpty
                    ? 'Nenhuma informação adicionada.'
                    : section.text,
                key: ValueKey('summary-${section.id}'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              if (!inline) ...[
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: edit),
              ],
            ],
          );
        },
      ),
    );
  }
}
