import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/pre_visit_report.dart';
import '../../data/models/report_clarification.dart';
import '../../data/repositories/clarification_repository.dart';
import 'report_controller.dart';

enum PreparationConversationStep {
  intro,
  method,
  text,
  audio,
  transcription,
  clarification,
  summary,
  questions,
  finalReview,
  completed,
}

/// Coordena etapas; relato, áudio e revisões continuam no ReportController.
class ConsultationPreparationController extends ChangeNotifier {
  ConsultationPreparationController(this.report, this.repository) {
    report.addListener(_changed);
  }
  final ReportController report;
  final ClarificationRepository repository;
  PreparationConversationStep step = PreparationConversationStep.intro;
  bool busy = false, _disposed = false, _active = false;
  Object? error;
  Future<bool> Function()? confirmReplacement;
  int _epoch = 0;
  String? _appointmentId;
  String answerDraft = '';
  String? selectedOption;
  String? _answerId;
  ReportClarification? get pending =>
      report.clarifications.where((row) => !row.answered).firstOrNull;
  int get stepperIndex => switch (step) {
    PreparationConversationStep.clarification => 1,
    PreparationConversationStep.summary => 2,
    PreparationConversationStep.questions => 3,
    PreparationConversationStep.finalReview ||
    PreparationConversationStep.completed => 4,
    _ => 0,
  };
  void _changed() {
    if (_disposed) return;
    if (_appointmentId != report.appointmentId) {
      _epoch++;
      _appointmentId = report.appointmentId;
      busy = false;
      error = null;
      answerDraft = '';
      selectedOption = null;
      _derive();
    }
    if (step == PreparationConversationStep.audio &&
        report.audioStatus == AudioDraftStatus.review) {
      step = PreparationConversationStep.transcription;
    }
    if (pending?.id != _answerId) {
      _answerId = pending?.id;
      answerDraft = '';
      selectedOption = null;
    }
    notifyListeners();
  }

  void _derive() {
    if (report.preparation.overview?.report.finalDone == true &&
        !report.summaryOutdated) {
      step = PreparationConversationStep.completed;
    } else if (pending != null ||
        (report.clarificationsCurrent && !report.clarificationsCompleted)) {
      step = PreparationConversationStep.clarification;
    } else if (report.hasSummary && !report.summaryOutdated) {
      step = PreparationConversationStep.summary;
    } else if (report.clarificationsCompleted) {
      step = PreparationConversationStep.summary;
    } else {
      step = report.text.trim().isEmpty
          ? PreparationConversationStep.intro
          : PreparationConversationStep.text;
    }
  }

  Future<void> enter() async {
    _active = true;
    _appointmentId = report.appointmentId;
    final epoch = ++_epoch;
    try {
      await report.refreshPersisted();
      if (!_valid(epoch)) return;
      _derive();
      error = null;
    } catch (e) {
      if (_valid(epoch)) error = e;
    }
    if (_valid(epoch)) notifyListeners();
  }

  bool _valid(int epoch) => !_disposed && _active && epoch == _epoch;
  void go(PreparationConversationStep value) {
    if (busy) return;
    if (step == PreparationConversationStep.audio ||
        step == PreparationConversationStep.transcription) {
      report.leaveAudio();
    }
    step = value;
    error = null;
    notifyListeners();
  }

  void leave() {
    if (_disposed) return;
    _active = false;
    _epoch++;
    busy = false;
    report.cancelProcessing(notify: false);
    report.leaveAudio();
    report.flushPendingEdits();
  }

  Future<void> _run(Future<void> Function(int epoch) action) async {
    if (busy || _disposed) return;
    _active = true;
    final epoch = ++_epoch;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action(epoch);
    } catch (e) {
      if (_valid(epoch)) error = e;
    } finally {
      if (_valid(epoch)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _accept(PreVisitReport saved, int epoch, int editEpoch) async {
    if (!_valid(epoch)) return;
    await report.acceptExternal(saved, expectedEditEpoch: editEpoch);
    if (report.conflict) throw report.saveError!;
  }

  Future<void> _next(int epoch) async {
    final edit = report.editEpoch;
    final value = await repository.next(report.appointmentId!);
    await _accept(value, epoch, edit);
    if (!_valid(epoch)) return;
    if (report.clarificationsCompleted) {
      await _organize(epoch);
    } else {
      step = PreparationConversationStep.clarification;
    }
  }

  Future<void> startComplement() => _run((epoch) async {
    if (report.text.trim().isEmpty || report.text.length > 20000) return;
    await report.saveDraft();
    if (!_valid(epoch) || report.conflict) return;
    step = PreparationConversationStep.clarification;
    notifyListeners();
    await _next(epoch);
  });
  Future<void> submitAnswer(
    ClarificationAnswerKind kind,
    String? text, {
    ReportClarification? question,
  }) => _run((epoch) async {
    final row = question ?? pending;
    if (row == null) return;
    await report.saveDraft();
    if (!_valid(epoch)) return;
    final edit = report.editEpoch;
    final saved = await repository.answer(
      report.appointmentId!,
      row.id,
      kind,
      text,
      report.contentRevision,
    );
    await _accept(saved, epoch, edit);
    if (!_valid(epoch)) return;
    if (question != null) {
      step = PreparationConversationStep.clarification;
      return;
    }
    await _next(epoch);
  });
  Future<void> retryComplement() => _run((epoch) async {
    await report.refreshPersisted();
    if (!_valid(epoch)) return;
    await _next(epoch);
  });
  Future<void> skipComplement() => _run((epoch) async {
    await report.saveDraft();
    if (!_valid(epoch)) return;
    final edit = report.editEpoch;
    final value = await repository.skip(report.appointmentId!);
    await _accept(value, epoch, edit);
    if (_valid(epoch)) await _organize(epoch);
  });
  Future<void> _organize(int epoch) async {
    step = PreparationConversationStep.summary;
    notifyListeners();
    if (!report.hasSummary || report.summaryOutdated) {
      if (report.hasSummary && confirmReplacement != null) {
        final confirmed = await confirmReplacement!();
        if (!_valid(epoch) || !confirmed) return;
      }
      final success = await report.organize();
      if (_valid(epoch) && !success) error = report.organizationError;
    }
  }

  Future<void> organize() => _run(_organize);
  Future<void> reviewSummary() => _run((epoch) async {
    await report.finishReview();
    if (_valid(epoch)) step = PreparationConversationStep.questions;
  });
  Future<void> reviewQuestions() => _run((epoch) async {
    await report.saveDraft();
    if (_valid(epoch)) step = PreparationConversationStep.finalReview;
  });
  Future<void> complete() => _run((epoch) async {
    await report.completePreparation();
    if (_valid(epoch)) step = PreparationConversationStep.completed;
  });
  Future<void> useTranscription() => _run((epoch) async {
    report.useTranscription();
    await report.saveDraft();
    if (_valid(epoch)) step = PreparationConversationStep.text;
  });
  void setAnswer(String value) {
    answerDraft = value;
    selectedOption = null;
    notifyListeners();
  }

  void selectOption(String value) {
    selectedOption = value;
    answerDraft = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    report.removeListener(_changed);
    answerDraft = '';
    selectedOption = null;
    super.dispose();
  }
}
