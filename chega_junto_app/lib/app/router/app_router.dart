import 'package:go_router/go_router.dart';
import '../../core/state/preparation_controller.dart';
import '../../core/widgets/pending_feature_page.dart';
import '../../features/appointments/presentation/pages/agenda_page.dart';
import '../../features/appointments/presentation/pages/appointment_details_page.dart';
import '../../features/checklist/presentation/pages/checklist_page.dart';
import '../../features/attendance/presentation/pages/attendance_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/onboarding/presentation/pages/welcome_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../demo_session.dart';
import 'app_routes.dart';

GoRouter createAppRouter({
  required DemoSession session,
  required PreparationController preparation,
  String? initialLocation,
}) => GoRouter(
  initialLocation: initialLocation ?? AppRoutes.welcome,
  refreshListenable: session,
  redirect: (context, state) {
    final public =
        state.matchedLocation == AppRoutes.welcome ||
        state.matchedLocation == AppRoutes.login;
    if (!public && !session.signedIn) return AppRoutes.login;
    if (state.matchedLocation == AppRoutes.login && session.signedIn) {
      return AppRoutes.home;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomePage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => LoginPage(session: session),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => HomePage(controller: preparation),
    ),
    GoRoute(
      path: AppRoutes.agenda,
      builder: (context, state) => AgendaPage(controller: preparation),
    ),
    GoRoute(
      path: AppRoutes.checklist,
      builder: (context, state) => ChecklistPage(controller: preparation),
    ),
    GoRoute(
      path: AppRoutes.attendance,
      builder: (context, state) => AttendancePage(controller: preparation),
    ),
    GoRoute(
      path: '/atendimentos/:id',
      builder: (context, state) => AppointmentDetailsPage(
        controller: preparation,
        appointmentId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) =>
          ProfilePage(controller: preparation, session: session),
    ),
    for (final entry in {
      AppRoutes.report: 'Relato pré-consulta',
      AppRoutes.summary: 'Revisão do relato',
      AppRoutes.notifications: 'Notificações',
    }.entries)
      GoRoute(
        path: entry.key,
        builder: (context, state) => PendingFeaturePage(
          title: entry.value,
          selectedIndex: entry.key == AppRoutes.notifications ? 0 : 2,
        ),
      ),
  ],
  errorBuilder: (context, state) =>
      const PendingFeaturePage(title: 'Página não encontrada'),
);
