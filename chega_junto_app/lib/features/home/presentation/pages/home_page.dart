import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/reference_artwork.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../data/mock/mock_notifications.dart';
import '../../../../core/widgets/appointment_card.dart';
import '../widgets/preparation_card.dart';
import '../widgets/quick_access_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller, required this.profile});
  final PreparationController controller;
  final ProfileController profile;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PreparationController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.background,
    bottomNavigationBar: const AppBottomNavigation(),
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([_controller, widget.profile]),
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_controller.failed || _controller.overview == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar seu preparo.'),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _controller.load,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          final overview = _controller.overview!;
          final unread =
              demoNotifications(
                    overview,
                    _controller.appointments,
                    _controller.reminders,
                  )
                  .where(
                    (item) =>
                        notificationVisible(
                          item,
                          widget.profile.notifications,
                        ) &&
                        item.unread &&
                        !widget.profile.isRead(item.id),
                  )
                  .length;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                20,
                AppSpacing.page,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandLogo(width: 185),
                      const Spacer(),
                      Semantics(
                        label: 'Notificações, há um lembrete',
                        button: true,
                        excludeSemantics: true,
                        child: IconButton.filledTonal(
                          onPressed: () =>
                              context.push(AppRoutes.notifications),
                          style: IconButton.styleFrom(
                            backgroundColor: context.appColors.blueSoft,
                            foregroundColor: context.appColors.ink,
                          ),
                          icon: Badge(
                            isLabelVisible: unread > 0,
                            smallSize: 6,
                            backgroundColor: context.appColors.primary,
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Olá, ${widget.profile.profile?.fullName.split(' ').first ?? overview.firstName}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 7,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Seu cuidado começa aqui',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                      Icon(
                        Icons.favorite_rounded,
                        color: context.appColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppointmentCard(
                    appointment: overview.nextAppointment,
                    onTap: () => context.push(AppRoutes.details),
                  ),
                  const SizedBox(height: 12),
                  PreparationCard(progress: overview.progress),
                  const SizedBox(height: 20),
                  Text(
                    'Acessos rápidos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _QuickAccessGrid(),
                  const SizedBox(height: 12),
                  AppSurface(
                    color: context.appColors.warningSoft,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconTile(
                          icon: Icons.notifications_rounded,
                          color: context.appColors.warning,
                          background: Color(0xFFFFE8BD),
                          size: 36,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lembrete',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                overview.reminder,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: context.appColors.ink),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _QuickAccessGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      QuickAccessTile(
        title: 'Agenda',
        description: 'Suas consultas e exames',
        icon: Icons.calendar_month_rounded,
        onTap: () => context.push(AppRoutes.agenda),
      ),
      QuickAccessTile(
        title: 'Checklist',
        description: 'Prepare-se para suas consultas',
        icon: Icons.check_box_rounded,
        color: context.appColors.tealDark,
        background: context.appColors.tealSoft,
        onTap: () => context.push(AppRoutes.checklist),
      ),
      QuickAccessTile(
        title: 'Documentos',
        description: 'Seus exames e comprovantes',
        icon: Icons.description_rounded,
        onTap: () => context.push(AppRoutes.checklist),
      ),
      QuickAccessTile(
        title: 'Resumo com IA',
        description: 'Organize seus exames e anotações',
        icon: Icons.notes_rounded,
        color: context.appColors.purple,
        background: context.appColors.purpleSoft,
        onTap: () => context.push(AppRoutes.summary),
      ),
    ];
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[0]),
            const SizedBox(width: 8),
            Expanded(child: items[1]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: items[2]),
            const SizedBox(width: 8),
            Expanded(child: items[3]),
          ],
        ),
      ],
    );
  }
}
