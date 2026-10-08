import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';
import '../utils/appointment_date.dart';
import 'app_surface.dart';
import 'confirmation_chip.dart';
import '../../data/models/appointment.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
  });
  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconTile(icon: Icons.calendar_month_rounded, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Próxima consulta',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          ConfirmationChip(
                            status: appointment.confirmationStatus,
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        appointment.specialty,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              appointment.facilityName,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.appColors.textSecondary,
                                  ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 25),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Metadata(
                    icon: Icons.calendar_today_outlined,
                    title: AppointmentDate.shortDate(appointment.dateTime),
                    subtitle: AppointmentDate.weekday(appointment.dateTime),
                  ),
                ),
                Container(
                  height: 32,
                  width: 1,
                  color: context.appColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _Metadata(
                    icon: Icons.schedule_rounded,
                    title: AppointmentDate.time(appointment.dateTime),
                    subtitle: 'Horário',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Metadata extends StatelessWidget {
  const _Metadata({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 23, color: context.appColors.primaryDark),
      const SizedBox(width: 9),
      Expanded(
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
