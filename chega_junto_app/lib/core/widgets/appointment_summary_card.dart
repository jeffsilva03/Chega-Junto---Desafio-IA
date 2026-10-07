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
  });
  final Appointment appointment;
  final bool compact;
  final bool attendance;
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
              icon: compact || attendance
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
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.facilityName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    Text(
                      appointment.professionalName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!attendance)
                      Text(
                        appointment.specialty,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    if (!attendance) const SizedBox(height: 8),
                    if (!attendance)
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
                title: AppointmentDate.fullDate(appointment.dateTime),
                subtitle: AppointmentDate.weekday(appointment.dateTime),
              ),
              _Detail(
                icon: Icons.schedule_rounded,
                title: AppointmentDate.time(appointment.dateTime),
                subtitle: 'Horário',
              ),
              _Detail(
                icon: Icons.location_on_outlined,
                title: appointment.facilityName,
                subtitle: 'Unidade',
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
      Icon(icon, color: AppColors.primaryDark, size: 23),
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
