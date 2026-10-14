import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/appointment_summary_card.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../../../../core/widgets/network_feedback.dart';
import '../../../../core/widgets/section_heading.dart';
import '../../../../data/models/appointment.dart';
import '../../../../data/models/checklist_item.dart';

class AppointmentDetailsPage extends StatelessWidget {
  const AppointmentDetailsPage({
    super.key,
    required this.controller,
    required this.appointmentId,
  });
  final PreparationController controller;
  final String appointmentId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _location(
    BuildContext context,
    Appointment appointment,
  ) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Como chegar'),
      content: SingleChildScrollView(
        child: Text(
          '${appointment.facilityName}\n${appointment.address}\n\nEste endereço é fictício. O mapa representa apenas a composição visual da demonstração.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Fechar'),
        ),
        TextButton(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: '${appointment.facilityName}\n${appointment.address}',
              ),
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Endereço fictício copiado.')),
              );
            }
          },
          child: const Text('Copiar endereço'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 1),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(56),
      backgroundColor: context.appColors.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        'Detalhes da consulta',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      centerTitle: true,
      leading: IconButton(
        onPressed: () => _back(context),
        tooltip: 'Voltar',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push(AppRoutes.notifications),
          tooltip: 'Notificações',
          icon: Badge(
            smallSize: 6,
            backgroundColor: context.appColors.primary,
            child: Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: PreparationView(
        requiresAppointment: false,
        controller: controller,
        builder: (context) => RemoteDetail<Appointment>(
          key: ValueKey(appointmentId),
          load: (retry) =>
              controller.loadAppointment(appointmentId, retry: retry),
          builder: (context, appointment) {
            final next =
                appointment.status == AppointmentStatus.scheduled &&
                controller.overview!.hasNextAppointment &&
                appointment.id == controller.overview!.nextAppointment.id;
            final documents = next
                ? controller.overview!.checklist
                      .where(
                        (item) => item.section == ChecklistSection.documents,
                      )
                      .toList()
                : const <ChecklistItem>[];
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppointmentSummaryCard(appointment: appointment),
                    const SizedBox(height: 12),
                    AppSurface(
                      border: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SectionHeading(
                                      title: 'Local do atendimento',
                                      icon: Icons.location_on_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      appointment.address,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const SizedBox(
                                width: 95,
                                height: 85,
                                child: _MapPreview(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Material(
                            color: context.appColors.blueSoft,
                            borderRadius: BorderRadius.circular(AppRadii.small),
                            child: InkWell(
                              onTap: () => _location(context, appointment),
                              borderRadius: BorderRadius.circular(
                                AppRadii.small,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.near_me_rounded,
                                      color: context.appColors.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Como chegar',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: context.appColors.primary,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: context.appColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (documents.isNotEmpty) ...[
                      AppSurface(
                        border: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeading(
                              title: 'O que levar',
                              icon: Icons.description_outlined,
                            ),
                            const SizedBox(height: 12),
                            for (final entry in documents.indexed) ...[
                              if (entry.$1 > 0) const Divider(),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.$2.isCompleted
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: entry.$2.isCompleted
                                          ? context.appColors.tealDark
                                          : context.appColors.muted,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        entry.$2.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    AppSurface(
                      border: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeading(
                            title: 'Orientações',
                            icon: Icons.info_rounded,
                            color: context.appColors.primaryDark,
                          ),
                          const SizedBox(height: 12),
                          for (final instruction in appointment.instructions)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: context.appColors.primaryDark,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      instruction,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'Em caso de imprevisto, procure o canal oficial da unidade para saber como remarcar ou cancelar.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (next) ...[
                      AppButton(
                        label: 'Ver checklist completo',
                        icon: Icons.chevron_right_rounded,
                        color: context.appColors.primaryDark,
                        onPressed: () => context.push(AppRoutes.checklist),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.attendance),
                        child: const Text('Confirmar presença'),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.report),
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('Relato pré-consulta'),
                      ),
                    ] else
                      AppButton(
                        label: 'Voltar à agenda',
                        icon: Icons.calendar_month_outlined,
                        onPressed: () => context.go(AppRoutes.agenda),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ilustração de mapa, sem localização real',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: CustomPaint(painter: _MapPainter(context.appColors)),
    ),
  );
}

class _MapPainter extends CustomPainter {
  const _MapPainter(this.colors);
  final AppPalette colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = colors.dark ? colors.background : const Color(0xFFF0F3F6),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * .7, 3, 22, 26),
      Paint()..color = const Color(0xFFDDF1DE),
    );
    canvas.drawRect(
      const Rect.fromLTWH(10, 20, 16, 14),
      Paint()..color = const Color(0xFFDDF1DE),
    );
    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 4;
    for (var i = -1; i < 5; i++) {
      canvas.drawLine(
        Offset(i * 32.0, 0),
        Offset(i * 32.0 + 50, size.height),
        street,
      );
      canvas.drawLine(
        Offset(0, i * 27.0),
        Offset(size.width, i * 27.0 - 35),
        street,
      );
    }
    final pin = Path()
      ..moveTo(size.width * .5, size.height * .73)
      ..quadraticBezierTo(
        size.width * .25,
        size.height * .42,
        size.width * .5,
        size.height * .32,
      )
      ..quadraticBezierTo(
        size.width * .75,
        size.height * .42,
        size.width * .5,
        size.height * .73,
      );
    canvas.drawPath(pin, Paint()..color = colors.primary);
    canvas.drawCircle(
      Offset(size.width * .5, size.height * .46),
      4,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) => colors != oldDelegate.colors;
}
