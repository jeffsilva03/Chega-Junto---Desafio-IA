import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/consultation_preparation_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/report_clarification.dart';
import 'preparation_conversation_widgets.dart';

class PreparationClarificationView extends StatefulWidget {
  const PreparationClarificationView({super.key, required this.conversation});
  final ConsultationPreparationController conversation;
  @override
  State<PreparationClarificationView> createState() =>
      _PreparationClarificationViewState();
}

class _PreparationClarificationViewState
    extends State<PreparationClarificationView> {
  String? editing;
  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation, report = conversation.report;
    return Column(
      key: const ValueKey('v9-clarification'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (report.clarifications.isEmpty)
          const PreparationMessage(
            text:
                'Obrigado por compartilhar! Para organizar melhor, posso fazer algumas perguntas rápidas.',
          ),
        for (final row in report.clarifications) ...[
          PreparationMessage(
            key: ValueKey('clarification-${row.id}'),
            text: row.questionText,
          ),
          const SizedBox(height: 10),
          if (row.answered) ...[
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: AppSurface(
                color: AppColors.tealSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Você',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(row.answerLabel),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: ValueKey('v9-answer-edit-${row.id}'),
                        onPressed: conversation.busy
                            ? null
                            : () => setState(
                                () =>
                                    editing = editing == row.id ? null : row.id,
                              ),
                        child: const Text('Editar resposta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (editing == row.id)
              ClarificationComposer(
                key: ValueKey('answer-edit-${row.id}'),
                question: row,
                conversation: conversation,
                editing: true,
                onSubmit: (kind, text) async {
                  await conversation.submitAnswer(kind, text, question: row);
                  if (mounted) setState(() => editing = null);
                },
              ),
          ] else if (editing == null && !conversation.busy)
            ClarificationComposer(
              key: ValueKey('answer-${row.id}'),
              question: row,
              conversation: conversation,
              onSubmit: (kind, text) => conversation.submitAnswer(kind, text),
            ),
          const SizedBox(height: 20),
        ],
        if (conversation.busy)
          const PreparationMessage(
            text: 'Preparando a próxima pergunta…',
            busy: true,
          ),
        if (!conversation.busy && report.clarificationsCompleted) ...[
          const Text(
            'Você já complementou seu relato. Pode seguir para o resumo.',
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Organizar resumo',
            onPressed: conversation.organize,
          ),
        ],
        if (!conversation.busy &&
            conversation.pending == null &&
            !report.clarificationsCompleted &&
            conversation.error == null)
          AppButton(
            label: 'Continuar complemento',
            onPressed: conversation.retryComplement,
          ),
        if (!conversation.busy && conversation.error == null)
          TextButton(
            onPressed: conversation.skipComplement,
            child: const Text('Continuar sem complemento'),
          ),
      ],
    );
  }
}

class ClarificationComposer extends StatefulWidget {
  const ClarificationComposer({
    super.key,
    required this.question,
    required this.conversation,
    required this.onSubmit,
    this.editing = false,
  });
  final ReportClarification question;
  final ConsultationPreparationController conversation;
  final Future<void> Function(ClarificationAnswerKind, String?) onSubmit;
  final bool editing;
  @override
  State<ClarificationComposer> createState() => _ClarificationComposerState();
}

class _ClarificationComposerState extends State<ClarificationComposer> {
  late bool free =
      widget.question.options.isEmpty ||
      widget.question.answerKind == ClarificationAnswerKind.text ||
      (!widget.editing && widget.conversation.answerDraft.isNotEmpty);
  late String? selected = widget.editing
      ? (widget.question.answerKind == ClarificationAnswerKind.option
            ? widget.question.answerText
            : null)
      : widget.conversation.selectedOption;
  late final input = TextEditingController(
    text: widget.editing
        ? widget.question.answerText ?? ''
        : widget.conversation.answerDraft,
  );
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 42),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!free)
          RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) {
              setState(() => selected = value);
              if (!widget.editing && value != null) {
                widget.conversation.selectOption(value);
              }
            },
            child: Column(
              children: [
                for (final entry in widget.question.options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected == entry.$2
                            ? context.appColors.tealSoft
                            : context.appColors.surface,
                        border: Border.all(
                          color: selected == entry.$2
                              ? context.appColors.teal
                              : context.appColors.border,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.medium),
                      ),
                      child: RadioListTile<String>(
                        key: ValueKey('v9-option-${entry.$1}'),
                        value: entry.$2,
                        title: Text(entry.$2),
                        activeColor: context.appColors.tealDark,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        dense: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (!free)
          TextButton(
            onPressed: () => setState(() => free = true),
            child: const Text('Responder com minhas palavras'),
          ),
        if (free)
          TextField(
            key: const ValueKey('v9-answer-input'),
            controller: input,
            minLines: 2,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Sua resposta',
              alignLabelWithHint: true,
            ),
            onChanged: (value) {
              if (!widget.editing) widget.conversation.setAnswer(value);
              setState(() {});
            },
          ),
        PopupMenuButton<ClarificationAnswerKind>(
          tooltip: 'Outras respostas',
          onSelected: (kind) => widget.onSubmit(kind, null),
          itemBuilder: (_) => [
            for (final kind in [
              ClarificationAnswerKind.dontKnow,
              ClarificationAnswerKind.dontRemember,
              ClarificationAnswerKind.preferNotToAnswer,
            ])
              PopupMenuItem(value: kind, child: Text(kind.label)),
          ],
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Não sei, não lembro ou prefiro não responder'),
          ),
        ),
        const SizedBox(height: 8),
        AppButton(
          key: const ValueKey('v9-clarification-continue'),
          label: widget.editing ? 'Salvar resposta' : 'Continuar',
          onPressed:
              (free ? input.text.trim().isEmpty : selected == null) ||
                  widget.conversation.busy
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  widget.onSubmit(
                    free
                        ? ClarificationAnswerKind.text
                        : ClarificationAnswerKind.option,
                    free ? input.text : selected,
                  );
                },
        ),
      ],
    ),
  );
}
