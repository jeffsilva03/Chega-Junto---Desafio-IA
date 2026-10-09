import 'package:flutter/material.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/profile_preferences.dart';
import '../../../profile/presentation/widgets/profile_components.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key, required this.controller});
  final ProfileController controller;
  Widget _option(
    BuildContext context,
    NotificationOption option,
    IconData icon,
    String title,
    String description,
  ) => SettingsOptionTile(
    key: ValueKey('notification-${option.name}'),
    icon: icon,
    title: title,
    description: description,
    value: controller.notifications.enabled(option),
    onChanged:
        controller.preferencesSaving ||
            option != NotificationOption.active &&
                !controller.notifications.enabled(NotificationOption.active)
        ? null
        : (value) => controller.setNotification(option, value),
  );
  @override
  Widget build(BuildContext context) => ProfileView(
    controller: controller,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ProfileScaffold(
        title: 'Configurações de notificações',
        subtitle: 'Escolha quais avisos deseja organizar nesta demonstração.',
        backTo: AppRoutes.notifications,
        children: [
          PreferenceSaveStatus(controller: controller),
          AppSurface(
            color: context.appColors.blueSoft,
            border: true,
            padding: const EdgeInsets.all(10),
            child: _option(
              context,
              NotificationOption.active,
              Icons.notifications_none_rounded,
              'Notificações ativas',
              'Preferências de avisos no aplicativo.',
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Tipos de notificações',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          ProfileSection(
            children: [
              _option(
                context,
                NotificationOption.appointments,
                Icons.calendar_month_outlined,
                'Lembretes de consultas',
                'Avisos sobre datas e horários da sua Agenda.',
              ),
              const Divider(),
              _option(
                context,
                NotificationOption.exams,
                Icons.description_outlined,
                'Lembretes de exames',
                'Datas e orientações previamente cadastradas.',
              ),
              const Divider(),
              _option(
                context,
                NotificationOption.medications,
                Icons.medication_outlined,
                'Lembretes de medicamentos',
                'Preferência para seus registros pessoais.',
              ),
              const Divider(),
              _option(
                context,
                NotificationOption.documents,
                Icons.mail_outline_rounded,
                'Resultados e documentos',
                'Preferência para documentos cadastrados.',
              ),
              const Divider(),
              _option(
                context,
                NotificationOption.confirmations,
                Icons.medical_services_outlined,
                'Confirmações e alterações',
                'Atualizações locais dos seus atendimentos.',
              ),
              const Divider(),
              _option(
                context,
                NotificationOption.system,
                Icons.campaign_outlined,
                'Comunicações do sistema',
                'Informações sobre o aplicativo.',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Como receber', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ProfileSection(
            children: [
              _option(
                context,
                NotificationOption.inApp,
                Icons.notifications_none_rounded,
                'Notificações no app',
                'Exibir os avisos demonstrativos na central.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const ProfileInfo(
            'Estas preferências não programam alarmes, push, e-mails ou mensagens.',
          ),
        ],
      ),
    ),
  );
}
