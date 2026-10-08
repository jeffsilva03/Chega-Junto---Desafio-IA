import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/appointment_date.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/health_record.dart';
import '../widgets/profile_components.dart';

class HealthHistoryPage extends StatefulWidget {
  const HealthHistoryPage({super.key, required this.controller});
  final ProfileController controller;
  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage> {
  HealthRecordType? _filter;
  static const _labels = [
    'Todos',
    'Consultas',
    'Exames',
    'Medicamentos',
    'Alergias',
    'Diagnósticos registrados',
  ];
  @override
  Widget build(BuildContext context) => ProfileView(
    controller: widget.controller,
    builder: (context) {
      final records =
          widget.controller.health!.history
              .where((r) => _filter == null || r.type == _filter)
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return ProfileScaffold(
        title: 'Histórico de saúde',
        subtitle: widget.controller.accessibility.simpleLanguage
            ? 'Seus registros de consultas, exames, medicamentos e alergias em um só lugar.'
            : 'Acompanhe registros anteriores de consultas, exames, diagnósticos, medicamentos e alergias.',
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _labels.length; i++)
                ChoiceChip(
                  label: Text(_labels[i]),
                  selected:
                      _filter ==
                      (i == 0 ? null : HealthRecordType.values[i - 1]),
                  showCheckmark: false,
                  selectedColor: context.appColors.primary,
                  labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        _filter ==
                            (i == 0 ? null : HealthRecordType.values[i - 1])
                        ? context.appColors.onPrimary
                        : context.appColors.textSecondary,
                  ),
                  side: BorderSide(color: context.appColors.border),
                  shape: const StadiumBorder(),
                  onSelected: (_) => setState(
                    () => _filter = i == 0
                        ? null
                        : HealthRecordType.values[i - 1],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (records.isEmpty)
            const ProfileInfo('Nenhum registro nesta categoria.'),
          for (final record in records) ...[
            Builder(
              builder: (context) {
                final appearance = healthAppearance(context, record.type);
                return InkWell(
                  onTap: () =>
                      context.push(AppRoutes.historyDetails(record.id)),
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  child: AppSurface(
                    border: true,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconTile(
                          icon: appearance.$1,
                          color: appearance.$2,
                          background: appearance.$3,
                          size: 48,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.type.label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${AppointmentDate.shortDate(record.dateTime)} de ${record.dateTime.year}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                record.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: context.appColors.textSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    },
  );
}
