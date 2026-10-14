import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/state/consultation_preparation_controller.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../widgets/preparation_clarification_view.dart';
import '../widgets/preparation_conversation_widgets.dart';
import '../widgets/preparation_report_composers.dart';
import '../widgets/preparation_review_cards.dart';
import '../widgets/report_components.dart';

class ConsultationPreparationPage extends StatefulWidget {
  const ConsultationPreparationPage({
    super.key,
    required this.controller,
    required this.conversation,
  });
  final ReportController controller;
  final ConsultationPreparationController conversation;
  @override
  State<ConsultationPreparationPage> createState() =>
      _ConsultationPreparationPageState();
}

class _ConsultationPreparationPageState
    extends State<ConsultationPreparationPage> {
  final scroll = ScrollController();
  String? lastQuestion;
  PreparationConversationStep? lastStep;
  @override
  void initState() {
    super.initState();
    widget.conversation.confirmReplacement = confirmReplacement;
    widget.conversation.addListener(_scrollToStep);
    unawaited(widget.conversation.enter());
  }

  void _scrollToStep() {
    final current = widget.conversation;
    if (lastStep != current.step) {
      lastStep = current.step;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.jumpTo(0);
      });
    }
    if (lastQuestion != current.pending?.id) {
      lastQuestion = current.pending?.id;
      if (lastQuestion != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !scroll.hasClients ||
              current.step != PreparationConversationStep.clarification) {
            return;
          }
          final reduce = MediaQuery.of(context).disableAnimations;
          if (reduce) {
            scroll.jumpTo(scroll.position.maxScrollExtent);
          } else {
            scroll.animateTo(
              scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    widget.conversation.confirmReplacement = null;
    widget.conversation.removeListener(_scrollToStep);
    widget.conversation.leave();
    scroll.dispose();
    super.dispose();
  }

  Future<bool> confirmReplacement() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Organizar o relato atualizado?'),
          content: const Text(
            'Um novo resumo substituirá as edições e perguntas desta versão. Seu relato original e o complemento serão mantidos.',
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
      ) ??
      false;

  void back() {
    final conversation = widget.conversation;
    FocusScope.of(context).unfocus();
    if (conversation.busy) {
      conversation.leave();
      conversation.go(PreparationConversationStep.text);
      return;
    }
    final previous = switch (conversation.step) {
      PreparationConversationStep.intro => null,
      PreparationConversationStep.method => PreparationConversationStep.intro,
      PreparationConversationStep.text => PreparationConversationStep.method,
      PreparationConversationStep.audio ||
      PreparationConversationStep.transcription =>
        PreparationConversationStep.method,
      PreparationConversationStep.clarification =>
        PreparationConversationStep.text,
      PreparationConversationStep.summary =>
        widget.controller.clarifications.isNotEmpty
            ? PreparationConversationStep.clarification
            : PreparationConversationStep.text,
      PreparationConversationStep.questions =>
        PreparationConversationStep.summary,
      PreparationConversationStep.finalReview =>
        PreparationConversationStep.questions,
      PreparationConversationStep.completed =>
        PreparationConversationStep.finalReview,
    };
    if (previous == null) {
      context.go(AppRoutes.checklist);
    } else {
      conversation.go(previous);
    }
  }

  Widget summary(BuildContext context) {
    final conversation = widget.conversation, report = widget.controller;
    return Column(
      key: const ValueKey('v9-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PreparationMessage(
          text: report.processing
              ? 'Estou organizando o que você contou…'
              : 'Com base no que você contou, organizei um resumo. Revise e edite se necessário.',
          busy: report.processing,
        ),
        const SizedBox(height: 18),
        if (report.hasSummary) OrganizedReportCard(controller: report),
        if (report.summaryOutdated && !report.processing) ...[
          const SizedBox(height: 16),
          const Text(
            'Suas informações mudaram. Organize novamente para atualizar o resumo.',
          ),
        ],
        if ((!report.hasContent || report.summaryOutdated) &&
            !conversation.busy) ...[
          const SizedBox(height: 16),
          AppButton(
            label: report.clarificationsCompleted
                ? 'Organizar resumo'
                : 'Retomar complemento',
            onPressed: report.clarificationsCompleted
                ? conversation.organize
                : conversation.startComplement,
          ),
        ],
        const SizedBox(height: 22),
        const Text('Está tudo certo com o resumo?'),
        const SizedBox(height: 12),
        if (report.hasContent && !report.summaryOutdated) ...[
          AppButton(
            label: 'Sim, continuar',
            busy: conversation.busy,
            onPressed: conversation.reviewSummary,
          ),
          TextButton(
            onPressed: conversation.busy
                ? null
                : () {
                    final section = report.sections.firstOrNull;
                    if (section != null) {
                      OrganizedReportCard(
                        controller: report,
                      ).edit(context, section);
                    }
                  },
            child: const Text('Quero editar'),
          ),
        ],
        TextButton(
          onPressed: conversation.busy
              ? null
              : () => conversation.go(PreparationConversationStep.text),
          child: const Text('Editar relato e complemento'),
        ),
        Text(
          report.realAudio
              ? 'A IA ajuda a organizar o que você contou. Revise tudo antes de continuar.'
              : 'Nesta demonstração, a organização é simulada.',
          style: TextStyle(color: context.appColors.textSecondary),
        ),
      ],
    );
  }

  Widget body(BuildContext context) {
    final conversation = widget.conversation, report = widget.controller;
    return switch (conversation.step) {
      PreparationConversationStep.intro => PreparationIntro(
        onStart: () => conversation.go(PreparationConversationStep.method),
      ),
      PreparationConversationStep.method => ReportMethodSelector(
        onText: () => conversation.go(PreparationConversationStep.text),
        onAudio: () => conversation.go(PreparationConversationStep.audio),
      ),
      PreparationConversationStep.text => TextReportComposer(
        conversation: conversation,
      ),
      PreparationConversationStep.audio => AudioComposer(
        conversation: conversation,
      ),
      PreparationConversationStep.transcription => TranscriptionReview(
        conversation: conversation,
      ),
      PreparationConversationStep.clarification => PreparationClarificationView(
        conversation: conversation,
      ),
      PreparationConversationStep.summary => summary(context),
      PreparationConversationStep.questions => Column(
        key: const ValueKey('v9-questions'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PreparationMessage(
            text:
                'Aqui estão algumas perguntas que você pode levar para a consulta. Selecione as que deseja e edite se quiser.',
          ),
          const SizedBox(height: 20),
          ConsultationQuestionsCard(controller: report),
          const SizedBox(height: 22),
          AppButton(
            label: 'Continuar',
            busy: conversation.busy,
            onPressed: conversation.reviewQuestions,
          ),
        ],
      ),
      PreparationConversationStep.finalReview => Column(
        key: const ValueKey('v9-final-review'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revisão final',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Confira tudo antes de concluir sua preparação.'),
          const SizedBox(height: 20),
          OrganizedReportCard(
            controller: report,
            readOnly: true,
            onEdit: () => conversation.go(PreparationConversationStep.summary),
          ),
          const SizedBox(height: 16),
          SelectedQuestionsReview(
            controller: report,
            onEdit: () =>
                conversation.go(PreparationConversationStep.questions),
          ),
          const SizedBox(height: 20),
          const Text(
            'Você decide o que compartilhar. Nada é enviado automaticamente a profissionais, UBS ou SUS.',
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Concluir preparação',
            busy: conversation.busy,
            onPressed: report.hasContent && !report.summaryOutdated
                ? conversation.complete
                : null,
          ),
        ],
      ),
      PreparationConversationStep.completed => PreparationCompletedView(
        appointment: report.preparation.overview!.nextAppointment,
        onReview: () =>
            conversation.go(PreparationConversationStep.finalReview),
      ),
    };
  }

  @override
  Widget build(BuildContext context) => PreparationView(
    controller: widget.controller.preparation,
    builder: (_) => ListenableBuilder(
      listenable: widget.conversation,
      builder: (context, _) {
        final conversation = widget.conversation;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) back();
          },
          child: Scaffold(
            backgroundColor: context.appColors.surface,
            appBar: AppBar(
              title: const Text('Preparar consulta'),
              centerTitle: true,
              backgroundColor: context.appColors.surface,
              foregroundColor: context.appColors.ink,
              leading: IconButton(
                tooltip: 'Voltar',
                onPressed: back,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : const AppBottomNavigation(selectedIndex: 2),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  PreparationStepper(index: conversation.stepperIndex),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReportSaveStatus(controller: widget.controller),
                          body(context),
                          if (conversation.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Semantics(
                                liveRegion: true,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      userError(
                                        conversation.error,
                                        'Não foi possível continuar agora. Seu relato foi preservado.',
                                      ),
                                    ),
                                    if (conversation.step ==
                                        PreparationConversationStep
                                            .clarification) ...[
                                      TextButton(
                                        onPressed: conversation.busy
                                            ? null
                                            : conversation.retryComplement,
                                        child: const Text('Tentar novamente'),
                                      ),
                                      TextButton(
                                        onPressed: conversation.busy
                                            ? null
                                            : conversation.skipComplement,
                                        child: const Text(
                                          'Continuar sem complemento',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
