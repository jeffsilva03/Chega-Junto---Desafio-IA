import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';
import '../../data/models/appointment.dart';
import '../utils/appointment_date.dart';
import 'app_surface.dart';
import 'confirmation_chip.dart';

class AppointmentSummaryCard extends StatelessWidget {
  const AppointmentSummaryCard({
    super.key,
    required this.appointment,
    this.compact = false,
    this.attendance = false,
    this.preVisit = false,
  });
  final Appointment appointment;
  final bool compact;
  final bool attendance;
  final bool preVisit;
  @override
  Widget build(BuildContext context) => AppSurface(
    border: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(
              icon: compact || attendance || preVisit
                  ? Icons.calendar_month_rounded
                  : appointment.type == AppointmentType.exam
                  ? Icons.science_rounded
                  : Icons.person_rounded,
              size: compact ? 52 : 60,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  if (compact) ...[
                    Text(
                      '${AppointmentDate.groupDate(appointment.dateTime)} · ${AppointmentDate.time(appointment.dateTime)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.facilityName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    if (preVisit)
                      Text(
                        appointment.facilityName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    Text(
                      appointment.professionalName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    if (!attendance && !preVisit)
                      Text(
                        appointment.specialty,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.muted,
                        ),
                      ),
                    if (!attendance && !preVisit) const SizedBox(height: 8),
                    if (!attendance &&
                        !preVisit &&
                        appointment.status != AppointmentStatus.scheduled)
                      Text(appointment.status.label),
                    if (!attendance &&
                        !preVisit &&
                        appointment.status == AppointmentStatus.scheduled)
                      ConfirmationChip(
                        status: appointment.confirmationStatus,
                        exam: appointment.type == AppointmentType.exam,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _Detail(
                icon: Icons.calendar_today_outlined,
                title: preVisit
                    ? '${AppointmentDate.shortDate(appointment.dateTime)} ${appointment.dateTime.year}'
                    : AppointmentDate.fullDate(appointment.dateTime),
                subtitle: preVisit
                    ? 'Data'
                    : AppointmentDate.weekday(appointment.dateTime),
              ),
              _Detail(
                icon: Icons.schedule_rounded,
                title: AppointmentDate.time(appointment.dateTime),
                subtitle: 'Horário',
              ),
              _Detail(
                icon: preVisit
                    ? Icons.medical_services_outlined
                    : Icons.location_on_outlined,
                title: preVisit
                    ? appointment.specialty
                    : appointment.facilityName,
                subtitle: preVisit ? 'Especialidade' : 'Unidade',
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: context.appColors.primaryDark, size: 23),
      const SizedBox(width: 9),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );
}
