import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/state/consultation_preparation_controller.dart';
import '../../../../core/widgets/app_button.dart';
import 'preparation_conversation_widgets.dart';

class TextReportComposer extends StatefulWidget {
  const TextReportComposer({super.key, required this.conversation});
  final ConsultationPreparationController conversation;
  @override
  State<TextReportComposer> createState() => _TextReportComposerState();
}

class _TextReportComposerState extends State<TextReportComposer> {
  late final input = TextEditingController(
    text: widget.conversation.report.text,
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation, report = conversation.report;
    if (input.text != report.text) {
      input.value = TextEditingValue(
        text: report.text,
        selection: TextSelection.collapsed(offset: report.text.length),
      );
    }
    return Column(
      key: const ValueKey('v9-text-input'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Conte o que deseja conversar',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('report-text'),
          controller: input,
          onChanged: report.setText,
          enabled: !conversation.busy,
          minLines: 8,
          maxLines: 14,
          maxLength: 20000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Seu relato',
            alignLabelWithHint: true,
            hintText:
                'Escreva com suas palavras como você tem se sentido, o que tem percebido e o que deseja conversar na consulta.',
          ),
        ),
        const SizedBox(height: 12),
        const Text('Você pode editar depois, se quiser.'),
        const SizedBox(height: 22),
        AppButton(
          label: 'Continuar',
          busy: conversation.busy,
          onPressed:
              report.text.trim().isEmpty ||
                  report.text.length > 20000 ||
                  report.conflict
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  conversation.startComplement();
                },
        ),
        TextButton(
          onPressed: conversation.busy
              ? null
              : () => conversation.go(PreparationConversationStep.audio),
          child: const Text('Prefiro gravar um áudio'),
        ),
        if (report.clarifications.isNotEmpty)
          TextButton(
            onPressed: () =>
                conversation.go(PreparationConversationStep.clarification),
            child: const Text('Rever complemento'),
          ),
      ],
    );
  }
}

class AudioComposer extends StatelessWidget {
  const AudioComposer({super.key, required this.conversation});
  final ConsultationPreparationController conversation;
  @override
  Widget build(BuildContext context) {
    final report = conversation.report,
        status = conversation.report.audioStatus;
    final recording = status == AudioDraftStatus.recording;
    final paused = status == AudioDraftStatus.paused;
    final transcribing = status == AudioDraftStatus.transcribing;
    final canStart =
        !recording && !paused && !transcribing && !report.audioBusy;
    return Column(
      key: const ValueKey('v9-audio'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          recording
              ? 'Gravando seu áudio'
              : paused
              ? 'Gravação pausada'
              : 'Gravar seu áudio',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            report.clock,
            textAlign: TextAlign.center,
            semanticsLabel: 'Duração ${report.seconds} segundos',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 22),
        ExcludeSemantics(
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                23,
                (index) => Flexible(
                  child: Container(
                    width: 4,
                    height: 12 + (index * 17 % 50).toDouble(),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: context.appColors.primary.withValues(
                        alpha: recording ? .9 : .3,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (!transcribing)
          Center(
            child: IconButton(
              key: const ValueKey('v9-audio-toggle'),
              tooltip: canStart
                  ? 'Iniciar gravação'
                  : recording
                  ? 'Pausar gravação'
                  : 'Continuar gravação',
              onPressed: report.audioBusy
                  ? null
                  : canStart
                  ? report.startAudio
                  : report.toggleAudio,
              icon: Icon(
                recording
                    ? Icons.pause_rounded
                    : paused
                    ? Icons.play_arrow_rounded
                    : Icons.mic_none_rounded,
                size: 36,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(72),
                backgroundColor: context.appColors.primary,
                foregroundColor: context.appColors.onPrimary,
              ),
            ),
          ),
        const SizedBox(height: 22),
        const PreparationTip(
          title: 'Dicas para um bom áudio',
          text:
              'Fale com calma. Conte o que deseja lembrar de conversar na consulta.',
          warning: true,
        ),
        const SizedBox(height: 14),
        Text(
          report.realAudio
              ? 'Use somente dados fictícios. Limite: 5 minutos e 10 MB. Você revisará a transcrição antes de usá-la.'
              : 'Demonstração simulada: nenhum microfone é acessado ou áudio enviado.',
        ),
        if (status == AudioDraftStatus.permissionDenied)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Não foi possível acessar o microfone.'),
          ),
        if (report.audioError != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(userError(report.audioError)),
          ),
        const SizedBox(height: 22),
        if (transcribing)
          const PreparationMessage(
            text: 'Transcrevendo o que você falou…',
            busy: true,
          ),
        if (recording || paused)
          AppButton(
            label: 'Parar gravação',
            outlined: true,
            icon: Icons.stop_rounded,
            color: AppColors.error,
            onPressed: report.audioBusy
                ? null
                : () async {
                    try {
                      await report.finishAudio();
                    } catch (_) {}
                  },
          ),
        TextButton(
          onPressed: transcribing
              ? null
              : () {
                  report.cancelAudio();
                  conversation.go(PreparationConversationStep.text);
                },
          child: const Text('Continuar digitando'),
        ),
        TextButton(
          onPressed: () async {
            await report.cancelAudio();
            conversation.go(PreparationConversationStep.method);
          },
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class TranscriptionReview extends StatelessWidget {
  const TranscriptionReview({super.key, required this.conversation});
  final ConsultationPreparationController conversation;
  @override
  Widget build(BuildContext context) {
    final report = conversation.report;
    return Column(
      key: const ValueKey('v9-transcription'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PreparationMessage(
          text: 'Transcrevi o que você falou. Revise antes de continuar.',
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: const ValueKey('audio-transcription'),
          initialValue: report.transcription,
          onChanged: report.setTranscription,
          minLines: 6,
          maxLines: 14,
          maxLength: 20000,
          decoration: const InputDecoration(
            labelText: 'Revise a transcrição',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Usar esta transcrição',
          busy: conversation.busy,
          onPressed: report.transcription.trim().isEmpty
              ? null
              : conversation.useTranscription,
        ),
        TextButton(
          onPressed: () async {
            await report.cancelAudio();
            conversation.go(PreparationConversationStep.audio);
          },
          child: const Text('Gravar novamente'),
        ),
        TextButton(
          onPressed: () async {
            await report.cancelAudio();
            conversation.go(PreparationConversationStep.text);
          },
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
