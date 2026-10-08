import 'package:flutter/material.dart';
import '../../../../core/utils/appointment_date.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/widgets/app_surface.dart';
import '../widgets/profile_components.dart';

class HealthHistoryDetailsPage extends StatelessWidget {
  const HealthHistoryDetailsPage({
    super.key,
    required this.controller,
    required this.recordId,
  });
  final ProfileController controller;
  final String recordId;
  Widget _textPanel(BuildContext context, String text) => AppSurface(
    color: context.appColors.background,
    padding: const EdgeInsets.all(12),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
  Widget _block(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) => ProfileSection(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.appColors.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => ProfileView(
    controller: controller,
    builder: (context) {
      final matches = controller.health!.history.where((r) => r.id == recordId);
      if (matches.isEmpty) {
        return const ProfileScaffold(
          title: 'Detalhes do histórico',
          backTo: AppRoutes.healthHistory,
          children: [ProfileInfo('Registro não encontrado.')],
        );
      }
      final record = matches.first;
      final appearance = healthAppearance(context, record.type);
      return ProfileScaffold(
        title: 'Detalhes do histórico',
        backTo: AppRoutes.healthHistory,
        children: [
          AppSurface(
            color: context.appColors.blueSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: appearance.$1,
                  color: appearance.$2,
                  background: appearance.$3,
                  size: 48,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.type.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        record.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppointmentDate.fullDate(record.dateTime)}  •  ${AppointmentDate.time(record.dateTime)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      if (record.facility.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                record.facility,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (record.professional.isNotEmpty) ...[
            ProfileSection(
              children: [
                SettingsOptionTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profissional',
                  description: record.professional,
                  onTap: () => profileInformation(
                    context,
                    'Profissional',
                    '${record.professional}\n${record.facility}\n\nInformação fictícia do registro. Não há contato com o profissional pelo aplicativo.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _block(
            context,
            record.type.label == 'Consulta'
                ? 'Motivo da consulta'
                : 'Sobre o registro',
            Icons.description_outlined,
            [_textPanel(context, record.reason)],
          ),
          const SizedBox(height: 10),
          _block(
            context,
            record.type.label == 'Consulta'
                ? 'Resumo da consulta'
                : 'Resumo do registro',
            Icons.article_outlined,
            [
              _textPanel(context, record.summary),
              if (record.notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Anotações',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _textPanel(
                  context,
                  record.notes.map((note) => '• $note').join('\n'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (record.documents.isNotEmpty)
            _block(
              context,
              'Documentos relacionados',
              Icons.attach_file_rounded,
              [
                for (final doc in record.documents) ...[
                  InkWell(
                    onTap: () =>
                        profileInformation(context, doc.title, doc.content),
                    child: AppSurface(
                      color: context.appColors.blueSoft,
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_outlined,
                            color: context.appColors.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.title,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  'Exemplo demonstrativo',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.visibility_outlined,
                            color: context.appColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
        ],
      );
    },
  );
}
