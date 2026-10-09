import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/utils/appointment_date.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/network_feedback.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../data/models/app_notification.dart';
import '../../../../data/models/profile_preferences.dart';
import '../../../profile/presentation/widgets/profile_components.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.profile,
    required this.preparation,
  });
  final ProfileController profile;
  final PreparationController preparation;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationCategory? _filter;
  bool _opening = false;
  Future<void> _open(AppNotification item) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.profile.markRead(item.id);
    } catch (e) {
      if (mounted) profileMessage(context, userError(e));
      return;
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted) return;
    final path = switch (item.destination) {
      NotificationDestination.appointment => AppRoutes.appointmentDetails(
        item.destinationId!,
      ),
      NotificationDestination.history => AppRoutes.historyDetails(
        item.destinationId!,
      ),
      NotificationDestination.medications => AppRoutes.medications,
      NotificationDestination.documents =>
        widget.preparation.overview?.hasNextAppointment == true &&
                widget.preparation.overview!.nextAppointment.id ==
                    item.destinationId
            ? AppRoutes.checklist
            : AppRoutes.appointmentDetails(item.destinationId!),
    };
    context.push(path);
  }

  @override
  Widget build(BuildContext context) => ProfileView(
    controller: widget.profile,
    builder: (context) {
      if (widget.profile.notificationsLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.profile.notificationError != null) {
        return NetworkFeedback(
          error: widget.profile.notificationError,
          onRetry: widget.profile.reloadNotifications,
        );
      }
      final reference =
          widget.preparation.overview?.referenceDate ?? DateTime.now();
      final all = widget.profile.inbox.items;
      final visible =
          all.where((n) => _filter == null || n.category == _filter).toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      String group(DateTime date) {
        final days = DateTime(
          reference.year,
          reference.month,
          reference.day,
        ).difference(DateTime(date.year, date.month, date.day)).inDays;
        return days == 0
            ? 'Hoje'
            : days == 1
            ? 'Ontem'
            : 'Esta semana';
      }

      final groups = <String, List<AppNotification>>{};
      for (final item in visible) {
        groups.putIfAbsent(group(item.dateTime), () => []).add(item);
      }
      return ProfileScaffold(
        title: 'Notificações',
        subtitle:
            'Acompanhe seus lembretes, confirmações e informações importantes.',
        action: IconButton(
          tooltip: 'Configurações de notificações',
          onPressed: () => context.push(AppRoutes.notificationSettings),
          icon: const Icon(Icons.settings_outlined),
        ),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final category in <NotificationCategory?>[
                null,
                ...NotificationCategory.values,
              ])
                ChoiceChip(
                  label: Text(
                    '${category?.label ?? 'Todas'} (${category == null ? all.length : all.where((n) => n.category == category).length})',
                  ),
                  selected: _filter == category,
                  showCheckmark: false,
                  selectedColor: context.appColors.primary,
                  shape: const StadiumBorder(),
                  side: BorderSide(color: context.appColors.border),
                  labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _filter == category
                        ? context.appColors.onPrimary
                        : context.appColors.textSecondary,
                  ),
                  onSelected: (_) => setState(() => _filter = category),
                ),
            ],
          ),
          if (!widget.profile.notifications.enabled(
            NotificationOption.active,
          )) ...[
            const SizedBox(height: 12),
            const ProfileInfo(
              'Avisos pausados. Ative-os nas configurações para voltar a exibi-los.',
            ),
          ],
          const SizedBox(height: 20),
          if (visible.isEmpty)
            const ProfileInfo(
              'Nenhum aviso para exibir com estas preferências e filtros.',
            ),
          for (final group in groups.entries) ...[
            Text(group.key, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final item in group.value) ...[
              Builder(
                builder: (context) {
                  final unread = item.unread && !widget.profile.isRead(item.id);
                  final icon = switch (item.category) {
                    NotificationCategory.reminder =>
                      item.destination == NotificationDestination.medications
                          ? Icons.medication_outlined
                          : Icons.notifications_none_rounded,
                    NotificationCategory.consultation =>
                      Icons.check_circle_outline_rounded,
                    NotificationCategory.exam => Icons.description_outlined,
                    NotificationCategory.system =>
                      Icons.chat_bubble_outline_rounded,
                  };
                  final color = switch (item.category) {
                    NotificationCategory.consultation =>
                      context.appColors.tealDark,
                    NotificationCategory.system => context.appColors.purple,
                    NotificationCategory.exam => context.appColors.error,
                    _ => context.appColors.primary,
                  };
                  final soft = switch (item.category) {
                    NotificationCategory.consultation =>
                      context.appColors.tealSoft,
                    NotificationCategory.system => context.appColors.purpleSoft,
                    NotificationCategory.exam => context.appColors.warningSoft,
                    _ => context.appColors.blueSoft,
                  };
                  return Semantics(
                    label: unread ? 'Não lida' : null,
                    child: InkWell(
                      onTap: _opening ? null : () => _open(item),
                      borderRadius: BorderRadius.circular(AppRadii.large),
                      child: AppSurface(
                        border: !unread,
                        color: unread ? soft : context.appColors.surface,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconTile(
                              icon: icon,
                              color: color,
                              background: soft,
                              size: 42,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        group.key == 'Esta semana'
                                            ? AppointmentDate.shortDate(
                                                item.dateTime,
                                              )
                                            : AppointmentDate.time(
                                                item.dateTime,
                                              ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.message,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color:
                                              context.appColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Column(
                              children: [
                                if (unread)
                                  Icon(
                                    Icons.circle,
                                    color: context.appColors.primary,
                                    size: 7,
                                  ),
                                const SizedBox(height: 12),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 22,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
          ],
          Text(
            'Avisos demonstrativos. Não são notificações enviadas por uma unidade de saúde.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}
