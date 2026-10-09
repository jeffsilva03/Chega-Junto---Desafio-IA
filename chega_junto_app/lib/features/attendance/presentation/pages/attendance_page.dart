import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/appointment_summary_card.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../../../../core/widgets/section_heading.dart';
import '../../../../data/models/appointment.dart';
import '../../../../data/models/checklist_item.dart';
import '../widgets/attendance_option_tile.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.controller});
  final PreparationController controller;
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  ConfirmationStatus? _selection;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _guidance({required bool reschedule}) {
    final appointment = widget.controller.overview!.nextAppointment;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          reschedule
              ? 'Ver como remarcar'
              : 'Orientações para avisar a unidade',
        ),
        scrollable: true,
        content: Text(
          reschedule
              ? 'Procure o canal oficial de ${appointment.facilityName} e informe a data e o horário do atendimento. Pergunte sobre os procedimentos e a disponibilidade para remarcar.\n\nO aplicativo não altera nem cancela a consulta.'
              : 'Procure os canais oficiais de ${appointment.facilityName}. Informe a data e o horário do atendimento e explique sua dificuldade para comparecer.\n\nNesta demonstração, nenhum aviso é enviado à unidade e os dados de contato não são reais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(ConfirmationStatus status) async {
    try {
      await widget.controller.setAttendance(status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userError(e, 'Não foi possível salvar. Tente novamente.'),
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final message = switch (status) {
      ConfirmationStatus.confirmed => 'Você marcou que vai comparecer.',
      ConfirmationStatus.unable =>
        'Você marcou que não poderá comparecer. Procure o canal oficial da unidade para avisar e saber como remarcar.',
      ConfirmationStatus.undecided =>
        'Você marcou que ainda não sabe. Pode revisar sua resposta depois e procurar a unidade se precisar de ajuda.',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resposta salva'),
        scrollable: true,
        content: Text(
          '$message\n\nA resposta foi registrada apenas neste aplicativo. Nenhuma informação foi enviada à unidade.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go(AppRoutes.home);
            },
            child: const Text('Ver minha preparação'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(76),
      backgroundColor: context.appColors.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Voltar',
        onPressed: _back,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etapa ${PreparationStage.attendance.index + 1} de ${PreparationStage.values.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          Text(
            'Confirmar presença',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ),
    body: SafeArea(
      top: false,
      child: PreparationView(
        controller: widget.controller,
        builder: (context) {
          final appointment = widget.controller.overview!.nextAppointment;
          final selected = _selection ?? appointment.confirmationStatus;
          final saving = widget.controller.saving;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sua resposta ajuda a organizar melhor sua preparação.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppointmentSummaryCard(
                    appointment: appointment,
                    attendance: true,
                  ),
                  const SizedBox(height: 24),
                  const SectionHeading(title: 'Selecione uma opção'),
                  const SizedBox(height: 12),
                  for (final option in const [
                    (
                      ConfirmationStatus.confirmed,
                      'Vou comparecer',
                      'Vou ao atendimento na data e horário agendados.',
                    ),
                    (
                      ConfirmationStatus.unable,
                      'Não poderei comparecer',
                      'Não consigo ir e preciso de orientações para avisar a unidade.',
                    ),
                    (
                      ConfirmationStatus.undecided,
                      'Ainda não sei',
                      'Ainda estou em dúvida sobre a minha presença.',
                    ),
                  ]) ...[
                    AttendanceOptionTile(
                      status: option.$1,
                      title: option.$2,
                      description: option.$3,
                      selected: selected == option.$1,
                      onTap: saving
                          ? null
                          : () => setState(() => _selection = option.$1),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  AppSurface(
                    color: context.appColors.blueSoft,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: context.appColors.primary,
                          size: 25,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Se você não puder ir, procure a unidade para avisar. Assim, outra pessoa poderá usar a vaga.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeading(title: 'Se precisar'),
                  const SizedBox(height: 10),
                  AppSurface(
                    border: true,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _HelpTile(
                          icon: Icons.calendar_month_outlined,
                          title: 'Ver como remarcar',
                          description: 'Consulte as orientações para remarcar.',
                          onTap: () => _guidance(reschedule: true),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Divider(),
                        ),
                        _HelpTile(
                          icon: Icons.phone_outlined,
                          title: 'Orientações para avisar a unidade',
                          description: 'Saiba como informar sua situação.',
                          onTap: () => _guidance(reschedule: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppButton(
                    key: const Key('attendance-save'),
                    label: saving ? 'Salvando resposta...' : 'Salvar resposta',
                    busy: saving,
                    onPressed: () => _save(selected),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: saving ? null : _back,
                    child: const Text('Responder depois'),
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

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.large),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: context.appColors.primary),
        ],
      ),
    ),
  );
}
