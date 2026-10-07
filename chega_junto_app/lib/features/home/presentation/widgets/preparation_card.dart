import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/checklist_item.dart';

class PreparationCard extends StatelessWidget {
  const PreparationCard({super.key, required this.progress});
  final PreparationProgress progress;
  static const _stages = [
    (PreparationStage.documents, 'Documentos e preparo', AppRoutes.checklist),
    (
      PreparationStage.attendance,
      'Confirmação de presença',
      AppRoutes.attendance,
    ),
    (PreparationStage.report, 'Relato pré-consulta', AppRoutes.report),
    (PreparationStage.finalReview, 'Revisão final', AppRoutes.summary),
  ];

  @override
  Widget build(BuildContext context) => AppSurface(
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Preparação ${progress.percentage}% concluída',
              child: SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress.fraction,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: AppColors.border,
                        color: AppColors.teal,
                      ),
                    ),
                    Text(
                      '${progress.percentage}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Você já se preparou',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${progress.completedCount} de ${progress.totalCount} etapas',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 5),
                      InkWell(
                        onTap: () => context.push(AppRoutes.checklist),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Ver tudo ›',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 7,
                      backgroundColor: AppColors.border,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ..._stages.indexed.map((entry) {
          final stage = entry.$2;
          final complete = progress.completed.contains(stage.$1);
          return Column(
            children: [
              if (entry.$1 > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 36),
                  child: Divider(),
                ),
              Semantics(
                label: '${stage.$2}, ${complete ? 'concluída' : 'pendente'}',
                button: true,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => context.push(stage.$3),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          complete
                              ? Icons.check_box_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: complete
                              ? AppColors.teal
                              : const Color(0xFFBDCBDF),
                          size: 25,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            stage.$2,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    ),
  );
}
