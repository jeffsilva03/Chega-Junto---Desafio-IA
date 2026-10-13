import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/appointment_summary_card.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../widgets/report_components.dart';

class PreVisitReportPage extends StatefulWidget {
  const PreVisitReportPage({super.key, required this.controller});
  final ReportController controller;
  @override
  State<PreVisitReportPage> createState() => _PreVisitReportPageState();
}

class _PreVisitReportPageState extends State<PreVisitReportPage> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.text);
    widget.controller.addListener(_sync);
  }

  void _sync() {
    if (_text.text != widget.controller.text) {
      _text.value = TextEditingValue(
        text: widget.controller.text,
        selection: TextSelection.collapsed(
          offset: widget.controller.text.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _text.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final controller = widget.controller;
    if (controller.text.trim().isEmpty) {
      reportMessage(context, 'Escreva seu relato ou grave um áudio.');
      return;
    }
    if (controller.hasSummary && !controller.summaryOutdated) {
      context.push(AppRoutes.summary);
      return;
    }
    if (controller.hasSummary) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Organizar o relato atualizado?'),
          content: const Text(
            'Um novo resumo substituirá as edições e perguntas desta versão. Seu relato original será mantido.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Organizar novamente'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    if (mounted) context.push(AppRoutes.processing);
  }

  @override
  Widget build(BuildContext context) => PreparationView(
    controller: widget.controller.preparation,
    builder: (context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => ReportScaffold(
        controller: widget.controller,
        title: 'Relato pré-consulta',
        eyebrow: 'Etapa 3 de 4',
        backTo: AppRoutes.checklist,
        subtitle:
            'Escreva o que está sentindo ou o que deseja conversar na consulta.',
        children: [
          AppointmentSummaryCard(
            appointment:
                widget.controller.preparation.overview!.nextAppointment,
            preVisit: true,
          ),
          const SizedBox(height: 16),
          AppSurface(
            border: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: context.appColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'O que você gostaria de contar ao profissional?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('report-text'),
                  controller: _text,
                  onChanged: widget.controller.setText,
                  minLines: 7,
                  maxLines: null,
                  maxLength: 500,
                  maxLengthEnforcement: MaxLengthEnforcement.none,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Escreva aqui seu relato...',
                    labelText: 'Seu relato',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final topic in [
                      'Dor ou sintoma',
                      'Exames e anotações',
                      'Pergunta para a consulta',
                    ])
                      ActionChip(
                        label: Text(topic),
                        backgroundColor: context.appColors.blueSoft,
                        shape: const StadiumBorder(),
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: context.appColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        onPressed: () => reportMessage(
                          context,
                          'Conte com suas palavras sobre $topic. Só será organizado o que você escrever.',
                        ),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(),
                ),
                Row(
                  children: [
                    IconTile(icon: Icons.mic_none_rounded, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Se preferir, experimente o relato por áudio.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (widget.controller.realAudio)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Use apenas dados fictícios nesta demonstração. Seu relato será enviado ao serviço de IA para organização. A IA organiza apenas o que você contou. Revise o resultado antes de continuar. Não substitui orientação de um profissional de saúde.',
              ),
            ),
          AppButton(label: 'Salvar e continuar', onPressed: _continue),
          const SizedBox(height: 10),
          AppButton(
            label: 'Gravar áudio',
            icon: Icons.mic_none_rounded,
            outlined: true,
            onPressed: () => context.push(AppRoutes.audio),
          ),
        ],
      ),
    ),
  );
}
