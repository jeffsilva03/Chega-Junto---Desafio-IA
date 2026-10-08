import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/appointment_summary_card.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../widgets/report_components.dart';

class AudioReportPage extends StatelessWidget {
  const AudioReportPage({super.key, required this.controller});
  final ReportController controller;

  Future<void> _finish(BuildContext context) async {
    try {
      await controller.finishAudio();
    } catch (_) {
      if (context.mounted) {
        reportMessage(
          context,
          'Não foi possível preparar a transcrição demonstrativa. Tente novamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PreparationView(
    controller: controller.preparation,
    builder: (context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.audioStatus;
        final recording = status == AudioDraftStatus.recording;
        final busy = status == AudioDraftStatus.transcribing;
        final review = status == AudioDraftStatus.review;
        return ReportScaffold(
          title: 'Gravação de áudio',
          subtitle:
              'Fale com calma. Depois você poderá revisar antes de continuar.',
          children: [
            AppointmentSummaryCard(
              appointment: controller.preparation.overview!.nextAppointment,
              preVisit: true,
            ),
            const SizedBox(height: 16),
            AppSurface(
              border: true,
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      switch (status) {
                        AudioDraftStatus.idle => 'Pronto para começar',
                        AudioDraftStatus.recording =>
                          '● Gravação simulada em andamento',
                        AudioDraftStatus.paused => 'Gravação pausada',
                        AudioDraftStatus.transcribing =>
                          'Preparando transcrição simulada...',
                        AudioDraftStatus.review =>
                          'Transcrição simulada pronta',
                      },
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: recording
                            ? context.appColors.error
                            : context.appColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.clock,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineLarge?.copyWith(fontSize: 40),
                    semanticsLabel: 'Duração ${controller.seconds} segundos',
                  ),
                  const SizedBox(height: 14),
                  ExcludeSemantics(
                    child: SizedBox(
                      height: 65,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _WavePainter(context.appColors, recording),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    )
                  else if (!review) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.appColors.blueSoft,
                      ),
                      child: IconButton.filled(
                        key: const ValueKey('audio-toggle'),
                        tooltip: status == AudioDraftStatus.idle
                            ? 'Iniciar gravação simulada'
                            : recording
                            ? 'Pausar gravação'
                            : 'Continuar gravação',
                        onPressed: status == AudioDraftStatus.idle
                            ? controller.startAudio
                            : controller.toggleAudio,
                        style: IconButton.styleFrom(
                          backgroundColor: context.appColors.primary,
                          foregroundColor: context.appColors.onPrimary,
                          minimumSize: const Size(76, 76),
                        ),
                        icon: Icon(
                          recording
                              ? Icons.pause_rounded
                              : Icons.mic_none_rounded,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status == AudioDraftStatus.idle
                          ? 'Toque no microfone para começar'
                          : recording
                          ? 'Toque no microfone para pausar'
                          : 'Toque no microfone para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.appColors.textSecondary),
                    ),
                  ],
                  if (review) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('audio-transcription'),
                      initialValue: controller.transcription,
                      onChanged: controller.setTranscription,
                      minLines: 3,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: 'Revise a transcrição simulada',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este exemplo usa seu relato escrito ou uma frase fictícia. Edite o texto antes de usá-lo.',
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppSurface(
              color: context.appColors.blueSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: context.appColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Demonstração: o microfone não é acessado e nenhum áudio é gravado ou enviado. A transcrição é simulada.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (review) ...[
              AppButton(
                label: 'Usar transcrição no relato',
                onPressed: () {
                  if (controller.transcription.trim().isEmpty) {
                    reportMessage(
                      context,
                      'Escreva algo na transcrição antes de continuar.',
                    );
                    return;
                  }
                  controller.useTranscription();
                  reportBack(context, AppRoutes.report);
                  reportMessage(
                    context,
                    'Transcrição adicionada ao relato. Revise antes de continuar.',
                  );
                },
              ),
              TextButton(
                onPressed: controller.startAudio,
                child: const Text('Recomeçar demonstração'),
              ),
            ] else
              AppButton(
                label: 'Concluir gravação',
                busy: busy,
                onPressed: recording || status == AudioDraftStatus.paused
                    ? () => _finish(context)
                    : null,
              ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Voltar para relato em texto',
              outlined: true,
              icon: null,
              onPressed: () {
                controller.pauseAudio();
                context.go(AppRoutes.report);
              },
            ),
          ],
        );
      },
    ),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.colors, this.active);
  final AppPalette colors;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    const heights = [
      8,
      15,
      24,
      40,
      29,
      16,
      9,
      20,
      33,
      49,
      31,
      17,
      10,
      26,
      18,
      12,
      24,
      14,
      25,
      40,
      44,
      54,
      34,
      24,
      17,
      10,
      21,
      38,
      53,
      38,
      20,
      26,
      16,
      9,
      8,
      12,
      27,
      35,
      24,
      16,
      9,
    ];
    for (var i = 0; i < heights.length; i++) {
      final x = size.width * (i + .5) / heights.length;
      final height = heights[i].toDouble();
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        Paint()
          ..color = active && i > 7 && i < 30 ? colors.primary : colors.border
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      active != oldDelegate.active || colors != oldDelegate.colors;
}
