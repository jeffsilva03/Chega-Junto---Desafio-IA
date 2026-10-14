import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/appointment_date.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/appointment.dart';

class PreparationStepper extends StatelessWidget {
  const PreparationStepper({super.key, required this.index});
  final int index;
  static const labels = [
    'Relato',
    'Complemento',
    'Resumo',
    'Perguntas',
    'Concluir',
  ];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              label: 'Etapa ${i + 1} de 5: ${labels[i]}',
              selected: i == index,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: i == 0
                              ? Colors.transparent
                              : context.appColors.border,
                        ),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == index
                              ? context.appColors.primary
                              : context.appColors.blueSoft,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: i == index
                                ? context.appColors.onPrimary
                                : context.appColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: i == 4
                              ? Colors.transparent
                              : context.appColors.border,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: i == index
                          ? context.appColors.ink
                          : context.appColors.textSecondary,
                      fontWeight: i == index
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class PreparationMessage extends StatelessWidget {
  const PreparationMessage({super.key, required this.text, this.busy = false});
  final String text;
  final bool busy;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: busy,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: context.appColors.primary,
          child: Icon(
            Icons.auto_awesome_outlined,
            color: context.appColors.onPrimary,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppSurface(
            color: AppColors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class PreparationTip extends StatelessWidget {
  const PreparationTip({
    super.key,
    required this.title,
    required this.text,
    this.warning = false,
  });
  final String title, text;
  final bool warning;
  @override
  Widget build(BuildContext context) => AppSurface(
    color: warning ? AppColors.warningSoft : AppColors.tealSoft,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          warning
              ? Icons.lightbulb_outline_rounded
              : Icons.info_outline_rounded,
          color: warning
              ? context.appColors.warning
              : context.appColors.tealDark,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 5),
              Text(text),
            ],
          ),
        ),
      ],
    ),
  );
}

class PreparationIntro extends StatelessWidget {
  const PreparationIntro({super.key, required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('v9-intro'),
    children: [
      const SizedBox(height: 26),
      SizedBox(
        width: 120,
        height: 95,
        child: Stack(
          children: [
            Positioned(
              left: 16,
              top: 10,
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 70,
                color: context.appColors.blueSoft,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 0,
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 54,
                color: context.appColors.primary,
              ),
            ),
            Positioned(
              left: 28,
              top: 25,
              child: Icon(
                Icons.more_horiz_rounded,
                size: 40,
                color: context.appColors.primary,
              ),
            ),
            Positioned(
              right: 4,
              top: 2,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 22,
                color: context.appColors.primary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Vamos preparar sua consulta?',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        'Conte como você tem se sentido e o que deseja conversar. Em seguida, farei algumas perguntas para organizar melhor as informações.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.appColors.textSecondary),
      ),
      const SizedBox(height: 30),
      const PreparationTip(
        title: 'Você no controle',
        text:
            'Este não é um atendimento médico. A IA ajuda a organizar suas informações para você levar à consulta.',
      ),
      const SizedBox(height: 16),
      AppButton(label: 'Começar relato', onPressed: onStart),
    ],
  );
}

class ReportMethodSelector extends StatelessWidget {
  const ReportMethodSelector({
    super.key,
    required this.onText,
    required this.onAudio,
  });
  final VoidCallback onText, onAudio;
  Widget _option(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    Key key,
    bool teal,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: context.appColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        key: key,
        contentPadding: const EdgeInsets.all(16),
        onTap: onTap,
        leading: IconTile(
          icon: icon,
          color: teal ? AppColors.tealDark : AppColors.primary,
          background: teal ? AppColors.tealSoft : AppColors.blueSoft,
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Como você prefere contar?',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text('Escolha a forma que for mais confortável para você.'),
      const SizedBox(height: 22),
      _option(
        context,
        'Escrever meu relato',
        'Conte com suas palavras o que deseja conversar.',
        Icons.edit_outlined,
        onText,
        const ValueKey('v9-method-text'),
        false,
      ),
      _option(
        context,
        'Gravar um áudio',
        'Fale com calma. Você poderá revisar a transcrição.',
        Icons.mic_none_rounded,
        onAudio,
        const ValueKey('v9-method-audio'),
        true,
      ),
      const SizedBox(height: 12),
      const PreparationTip(
        title: 'Dica',
        text:
            'Se quiser, conte quando percebeu, em qual contexto acontece e o que deseja conversar com o profissional.',
      ),
    ],
  );
}

class PreparationCompletedView extends StatelessWidget {
  const PreparationCompletedView({
    super.key,
    required this.appointment,
    required this.onReview,
  });
  final Appointment appointment;
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('v9-completed'),
    children: [
      const SizedBox(height: 24),
      CircleAvatar(
        radius: 44,
        backgroundColor: context.appColors.tealSoft,
        child: Icon(
          Icons.check_rounded,
          color: context.appColors.tealDark,
          size: 54,
        ),
      ),
      const SizedBox(height: 22),
      Text(
        'Preparação concluída!',
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
      const Text(
        'Suas informações estão organizadas. Agora é só levar para a consulta.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 26),
      AppSurface(
        color: AppColors.blueSoft,
        child: Row(
          children: [
            const IconTile(icon: Icons.calendar_month_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '${AppointmentDate.groupDate(appointment.dateTime)} • ${AppointmentDate.time(appointment.dateTime)}',
                  ),
                  Text(appointment.specialty),
                  Text(appointment.professionalName),
                  Text(appointment.facilityName),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const PreparationTip(
        title: 'Antes da consulta',
        text:
            'Leve suas anotações. Você decide o que deseja compartilhar com o profissional de saúde.',
        warning: true,
      ),
      const SizedBox(height: 22),
      AppButton(
        label: 'Voltar para início',
        color: AppColors.tealDark,
        onPressed: () => context.go(AppRoutes.home),
      ),
      TextButton(onPressed: onReview, child: const Text('Revisar preparação')),
    ],
  );
}
