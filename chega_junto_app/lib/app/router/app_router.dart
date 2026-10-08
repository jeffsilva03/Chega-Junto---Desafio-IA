import 'package:go_router/go_router.dart';
import '../../core/state/preparation_controller.dart';
import '../../core/state/report_controller.dart';
import '../../features/pre_visit_report/presentation/pages/pre_visit_report_page.dart';
import '../../features/pre_visit_report/presentation/pages/audio_report_page.dart';
import '../../features/ai_summary/presentation/pages/report_processing_page.dart';
import '../../features/ai_summary/presentation/pages/ai_summary_page.dart';
import '../../features/questions/presentation/pages/consultation_questions_page.dart';
import '../../core/state/profile_controller.dart';
import '../../core/state/speech_controller.dart';
import '../../features/profile/presentation/pages/personal_data_page.dart';
import '../../features/profile/presentation/pages/medications_allergies_page.dart';
import '../../features/profile/presentation/pages/health_history_page.dart';
import '../../features/profile/presentation/pages/health_history_details_page.dart';
import '../../features/profile/presentation/pages/accessibility_page.dart';
import '../../features/profile/presentation/pages/help_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/notifications/presentation/pages/notification_settings_page.dart';
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
  required ProfileController profile,
  required SpeechController speech,
  required ReportController report,
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
      builder: (context, state) =>
          HomePage(controller: preparation, profile: profile),
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
      builder: (context, state) => ProfilePage(
        controller: preparation,
        session: session,
        profileController: profile,
      ),
    ),
    GoRoute(
      path: AppRoutes.personalData,
      builder: (context, state) => PersonalDataPage(controller: profile),
    ),
    GoRoute(
      path: AppRoutes.medications,
      builder: (context, state) =>
          MedicationsAllergiesPage(controller: profile),
    ),
    GoRoute(
      path: AppRoutes.healthHistory,
      builder: (context, state) => HealthHistoryPage(controller: profile),
    ),
    GoRoute(
      path: '/perfil/historico/:id',
      builder: (context, state) => HealthHistoryDetailsPage(
        controller: profile,
        recordId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.accessibility,
      builder: (context, state) =>
          AccessibilityPage(controller: profile, speech: speech),
    ),
    GoRoute(
      path: AppRoutes.help,
      builder: (context, state) => HelpPage(controller: profile),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) =>
          NotificationsPage(profile: profile, preparation: preparation),
    ),
    GoRoute(
      path: AppRoutes.notificationSettings,
      builder: (context, state) =>
          NotificationSettingsPage(controller: profile),
    ),
    GoRoute(
      path: AppRoutes.report,
      builder: (context, state) => PreVisitReportPage(controller: report),
    ),
    GoRoute(
      path: AppRoutes.audio,
      builder: (context, state) => AudioReportPage(controller: report),
    ),
    GoRoute(
      path: AppRoutes.processing,
      builder: (context, state) => ReportProcessingPage(controller: report),
    ),
    GoRoute(
      path: AppRoutes.summary,
      builder: (context, state) => AiSummaryPage(controller: report),
    ),
    GoRoute(
      path: AppRoutes.questions,
      builder: (context, state) =>
          ConsultationQuestionsPage(controller: report),
    ),
  ],
  errorBuilder: (context, state) =>
      const PendingFeaturePage(title: 'Página não encontrada'),
);
