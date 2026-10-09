import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/utils/appointment_date.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/appointment_card.dart';
import '../../../../core/widgets/confirmation_chip.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../../../../core/widgets/reference_artwork.dart';
import '../../../../data/models/appointment.dart';
import '../../../../data/models/appointment_reminder.dart';
import '../widgets/new_reminder_popover.dart';

enum _Filter { all, consultations, exams, reminders }

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.controller});
  final PreparationController controller;
  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final _search = TextEditingController();
  final _reminderAnchor = GlobalKey();
  final _navigationAnchor = GlobalKey();
  bool _upcoming = true;
  _Filter _filter = _Filter.all;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Entry> _entries() {
    final controller = widget.controller;
    final today = DateUtils.dateOnly(controller.overview!.referenceDate);
    final query = _search.text.trim().toLowerCase();
    final entries = [
      for (final appointment in controller.appointments)
        _Entry.appointment(appointment),
      for (final reminder in controller.reminders) _Entry.reminder(reminder),
    ];
    return entries.where((entry) {
      final day = DateUtils.dateOnly(entry.date);
      final periodMatches = _upcoming ? !day.isBefore(today) : day == today;
      final typeMatches = switch (_filter) {
        _Filter.all => true,
        _Filter.consultations =>
          entry.appointment?.type == AppointmentType.consultation,
        _Filter.exams => entry.appointment?.type == AppointmentType.exam,
        _Filter.reminders => entry.reminder != null,
      };
      final text =
          '${entry.title} ${entry.reminder?.title ?? ''} ${entry.appointment?.facilityName ?? ''} ${entry.appointment?.professionalName ?? ''}'
              .toLowerCase();
      return periodMatches && typeMatches && text.contains(query);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _addReminder() async {
    final box =
        _reminderAnchor.currentContext!.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final navigation =
        _navigationAnchor.currentContext!.findRenderObject()! as RenderBox;
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.transparent,
      useSafeArea: false,
      builder: (context) => NewReminderPopover(
        controller: widget.controller,
        anchor: anchor,
        footerTop: navigation.localToGlobal(Offset.zero).dy,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lembrete salvo na Agenda.')),
      );
    }
  }

  void _reminderInfo(AppointmentReminder reminder) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Lembrete'),
      content: Text(
        '${reminder.title}\n\n${AppointmentDate.fullDate(reminder.dateTime)} · ${AppointmentDate.time(reminder.dateTime)}\n\nLembrete local da demonstração.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.background,
    bottomNavigationBar: AppBottomNavigation(
      key: _navigationAnchor,
      selectedIndex: 1,
    ),
    body: SafeArea(
      bottom: false,
      child: PreparationView(
        requiresAppointment: false,
        controller: widget.controller,
        builder: (context) {
          final controller = widget.controller;
          final overview = controller.overview!;
          final entries = _entries();
          final grouped = <DateTime, List<_Entry>>{};
          for (final entry in entries) {
            grouped
                .putIfAbsent(DateUtils.dateOnly(entry.date), () => [])
                .add(entry);
          }
          final counts = {
            _Filter.all:
                controller.appointments.length + controller.reminders.length,
            _Filter.consultations: controller.appointments
                .where((a) => a.type == AppointmentType.consultation)
                .length,
            _Filter.exams: controller.appointments
                .where((a) => a.type == AppointmentType.exam)
                .length,
            _Filter.reminders: controller.reminders.length,
          };
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (controller.reminderRefreshError != null) ...[
                    const Text(
                      'Lembrete salvo. Não foi possível atualizar a lista completa.',
                    ),
                    TextButton(
                      onPressed: controller.load,
                      child: const Text('Recarregar Agenda'),
                    ),
                  ],
                  Row(
                    children: [
                      const BrandLogo(width: 185),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: () => context.push(AppRoutes.notifications),
                        tooltip: 'Notificações',
                        style: IconButton.styleFrom(
                          backgroundColor: context.appColors.blueSoft,
                        ),
                        icon: Badge(
                          smallSize: 6,
                          backgroundColor: context.appColors.primary,
                          child: Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Seus próximos atendimentos e lembretes.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: context.appColors.dark
                          ? context.appColors.blueSoft
                          : const Color(0xFFEAF0F7),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        for (final tab in [('Hoje', false), ('Próximos', true)])
                          Expanded(
                            child: Semantics(
                              selected: _upcoming == tab.$2,
                              button: true,
                              child: InkWell(
                                onTap: () => setState(() => _upcoming = tab.$2),
                                borderRadius: BorderRadius.circular(28),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _upcoming == tab.$2
                                        ? context.appColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Text(
                                    tab.$1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _upcoming == tab.$2
                                          ? context.appColors.onPrimary
                                          : context.appColors.textSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('agenda-search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar consultas, exames ou locais...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final filter in [
                        (_Filter.all, 'Todos', null),
                        (
                          _Filter.consultations,
                          'Consultas',
                          Icons.medical_services_outlined,
                        ),
                        (_Filter.exams, 'Exames', Icons.description_outlined),
                        (
                          _Filter.reminders,
                          'Lembretes',
                          Icons.notifications_none_rounded,
                        ),
                      ])
                        ChoiceChip(
                          shape: const StadiumBorder(),
                          label: Text('${filter.$2} (${counts[filter.$1]})'),
                          avatar: filter.$3 == null
                              ? null
                              : Icon(filter.$3, size: 16),
                          selected: _filter == filter.$1,
                          showCheckmark: false,
                          selectedColor: context.appColors.blueSoft,
                          backgroundColor: context.appColors.surface,
                          side: BorderSide(color: context.appColors.border),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: _filter == filter.$1
                                ? context.appColors.primary
                                : context.appColors.textSecondary,
                            fontWeight: _filter == filter.$1
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              setState(() => _filter = filter.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (overview.hasNextAppointment)
                    AppointmentCard(
                      appointment: overview.nextAppointment,
                      onTap: () => context.push(
                        AppRoutes.appointmentDetails(
                          overview.nextAppointment.id,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: _reminderAnchor,
                      onPressed: overview.hasNextAppointment
                          ? _addReminder
                          : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Adicionar lembrete'),
                    ),
                  ),
                  if (entries.isEmpty)
                    AppSurface(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          _search.text.isNotEmpty
                              ? 'Nenhum resultado para essa busca.'
                              : _upcoming
                              ? 'Nenhum item neste filtro.'
                              : 'Nenhum atendimento ou lembrete para hoje.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final group in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 12),
                      child: Text(
                        AppointmentDate.groupDate(group.key),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    for (final entry in group.value) ...[
                      _AgendaTile(
                        entry: entry,
                        onTap: () => entry.appointment != null
                            ? context.push(
                                AppRoutes.appointmentDetails(
                                  entry.appointment!.id,
                                ),
                              )
                            : _reminderInfo(entry.reminder!),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _Entry {
  const _Entry.appointment(Appointment value)
    : appointment = value,
      reminder = null;
  const _Entry.reminder(AppointmentReminder value)
    : appointment = null,
      reminder = value;
  final Appointment? appointment;
  final AppointmentReminder? reminder;
  DateTime get date => appointment?.dateTime ?? reminder!.dateTime;
  String get title => reminder != null
      ? 'Lembrete'
      : appointment!.title == 'Consulta clínica'
      ? appointment!.specialty
      : appointment!.title;
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({required this.entry, required this.onTap});
  final _Entry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final appointment = entry.appointment;
    final exam = appointment?.type == AppointmentType.exam;
    final reminder = entry.reminder != null;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: AppSurface(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    icon: reminder
                        ? Icons.notifications_rounded
                        : exam
                        ? Icons.science_rounded
                        : Icons.calendar_month_rounded,
                    color: reminder
                        ? context.appColors.warning
                        : exam
                        ? context.appColors.purple
                        : context.appColors.primary,
                    background: reminder
                        ? context.appColors.warningSoft
                        : exam
                        ? context.appColors.purpleSoft
                        : context.appColors.blueSoft,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          appointment?.facilityName ?? entry.reminder!.title,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded, size: 17),
                                const SizedBox(width: 5),
                                Text(
                                  AppointmentDate.time(entry.date),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            if (appointment != null)
                              ConfirmationChip(
                                status: appointment.confirmationStatus,
                                exam: exam,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 22),
                ],
              ),
              if (exam) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.appColors.purpleSoft,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment!.instructions.first,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        appointment.instructions.last,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
