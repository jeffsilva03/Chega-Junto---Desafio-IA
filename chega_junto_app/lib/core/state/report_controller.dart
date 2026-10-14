import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/organized_report.dart';
import '../../data/models/pre_visit_report.dart';
import '../../data/models/report_clarification.dart';
import '../network/api_exception.dart';
import '../services/ai_assistant_service.dart';
import '../services/audio_draft_service.dart';
import '../services/audio_capture_service.dart';
import 'preparation_controller.dart';

enum AudioDraftStatus {
  idle,
  recording,
  paused,
  transcribing,
  review,
  permissionDenied,
  error,
}

/// One draft per appointment, kept outside routes for the lifetime of the session.
class ReportController extends ChangeNotifier {
  ReportController(
    this.preparation,
    this.assistant,
    this.audio, {
    this.autosaveDelay,
    this.capture,
  }) {
    preparation.addListener(_initialize);
    _initialize();
  }
  final PreparationController preparation;
  final AiAssistantService assistant;
  final AudioDraftService audio;
  final AudioCaptureService? capture;
  bool get realAudio => capture != null;
  bool audioBusy = false;
  Object? audioError, organizationError;
  int _audioGeneration = 0;
  final Duration? autosaveDelay;
  String contentRevision = '0';
  String? reviewedRevision, finalReviewRevision;
  DateTime? reviewedAt, finalReviewAt;
  bool saving = false,
      conflict = false,
      _dirty = false,
      _clearRequested = false;
  Object? saveError;
  PreVisitReport? preservedDraft;
  String? _appointmentId;
  String? get appointmentId => _appointmentId;
  int get editEpoch => _revision;
  String? currentSourceHash, _generatedSourceHash, _clarificationsSourceText;
  List<ReportClarification> _clarifications = const [];
  bool _clarificationsCompleted = false;
  bool get clarificationsCurrent => _clarificationsSourceText == text;
  bool get clarificationsCompleted =>
      clarificationsCurrent && _clarificationsCompleted;
  List<ReportClarification> get clarifications =>
      clarificationsCurrent ? _clarifications : const [];
  Timer? _autosave;
  Future<void> _pendingWrite = Future.value();
  String text = '', processedText = '', transcription = '';
  List<ReportSection> sections = const [];
  List<ConsultationQuestion> questions = const [];
  bool processing = false,
      failed = false,
      reviewed = false,
      showSuggestions = true;
  AudioDraftStatus audioStatus = AudioDraftStatus.idle;
  int seconds = 0;
  bool _initialized = false, _disposed = false;
  int _generation = 0, _questionSequence = 0, _revision = 0;
  Timer? _timer;
  bool get hasSummary => sections.isNotEmpty;
  bool get hasUnsavedChanges => _dirty;
  bool get summaryOutdated =>
      hasSummary &&
      (processedText != text ||
          (_generatedSourceHash != null &&
              currentSourceHash != null &&
              _generatedSourceHash != currentSourceHash));
  bool get hasContent =>
      sections.any((section) => section.text.trim().isNotEmpty);
  List<ConsultationQuestion> get selectedQuestions =>
      List.unmodifiable(questions.where((question) => question.selected));

  void _markChanged() {
    _revision++;
    _dirty = true;
    reviewed = false;
    preparation.invalidateFinalReview();
    _autosave?.cancel();
    if (autosaveDelay != null && !conflict) {
      _autosave = Timer(autosaveDelay!, () {
        saveDraft().catchError((Object _) {});
      });
    }
  }

  String get clock =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  void _initialize() {
    if (preparation.overview == null ||
        !preparation.overview!.hasNextAppointment) {
      return;
    }
    final nextId = preparation.overview!.nextAppointment.id;
    if (_initialized && nextId == _appointmentId) return;
    if (_initialized) {
      cancelProcessing(notify: false);
      unawaited(cancelAudio(notify: false));
      if (_dirty || saveError != null) preservedDraft = _snapshot();
      _autosave?.cancel();
      _revision++;
      _dirty = false;
      _clearRequested = false;
      conflict = false;
      saveError = null;
    }
    _initialized = true;
    _appointmentId = preparation.overview!.nextAppointment.id;
    _hydrate(preparation.overview!.report);
    notifyListeners();
  }

  void _hydrate(PreVisitReport value) {
    text = value.originalText;
    sections = value.sections;
    questions = value.questions;
    processedText = value.organizationCurrent ? text : '\u0000';
    contentRevision = value.contentRevision;
    reviewed = value.reviewed;
    reviewedRevision = value.reviewedRevision;
    reviewedAt = value.reviewedAt;
    finalReviewRevision = value.finalReviewRevision;
    finalReviewAt = value.finalReviewAt;
    currentSourceHash = value.currentSourceHash;
    _generatedSourceHash = value.organizationCurrent
        ? value.currentSourceHash
        : null;
    _clarifications = value.clarifications;
    _clarificationsSourceText = value.clarificationsCurrent
        ? value.originalText
        : value.clarificationsSourceText;
    _clarificationsCompleted = value.clarificationsCompleted;
  }

  PreVisitReport _snapshot() => PreVisitReport(
    appointmentId: _appointmentId ?? preparation.overview!.nextAppointment.id,
    originalText: text,
    updatedAt: DateTime.now(),
    contentRevision: contentRevision,
    sections: sections,
    questions: questions,
    organizationCurrent: hasSummary && !summaryOutdated,
    reviewed: reviewed,
    organizedSummary: sections
        .where((s) => s.text.trim().isNotEmpty)
        .map((s) => '${s.title}\n${s.text}')
        .join('\n\n'),
    suggestedQuestions: selectedQuestions.map((q) => q.text).toList(),
    currentSourceHash: currentSourceHash,
    organizationSourceHash: _generatedSourceHash,
    clarifications: _clarifications,
    clarificationsCurrent: clarificationsCurrent,
    clarificationsCompleted: clarificationsCompleted,
    clarificationsSourceText: _clarificationsSourceText,
  );

  Future<void> acceptExternal(
    PreVisitReport value, {
    required int expectedEditEpoch,
  }) => _serialize(() async {
    if (_disposed || value.appointmentId != _appointmentId) return;
    if (expectedEditEpoch != _revision || _dirty) {
      preservedDraft = _snapshot();
      conflict = true;
      saveError = const ConflictException(code: 'revision_conflict');
      notifyListeners();
      return;
    }
    _hydrate(value);
    preparation.acceptReport(value);
    notifyListeners();
  });

  Future<void> refreshPersisted() async {
    await saveDraft();
    final epoch = _revision, id = _appointmentId;
    if (id == null) return;
    final value = await preparation.repository.loadReport(id);
    if (value != null) await acceptExternal(value, expectedEditEpoch: epoch);
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _pendingWrite.then((_) => action());
    _pendingWrite = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  void _accept(PreVisitReport saved, PreVisitReport sent, int editVersion) {
    if (_disposed || saved.appointmentId != _appointmentId) return;
    contentRevision = saved.contentRevision;
    if (editVersion == _revision) {
      _hydrate(saved);
      _dirty = false;
    } else {
      // An edit made during HTTP must survive; reconcile only assigned child IDs.
      final sectionIds = {
        for (
          var i = 0;
          i < sent.sections.length && i < saved.sections.length;
          i++
        )
          sent.sections[i].id: saved.sections[i].serverId,
      };
      final questionIds = {
        for (
          var i = 0;
          i < sent.questions.length && i < saved.questions.length;
          i++
        )
          sent.questions[i].id: saved.questions[i].serverId,
      };
      sections = [
        for (final s in sections)
          ReportSection(
            id: s.id,
            title: s.title,
            text: s.text,
            sectionKey: s.sectionKey,
            serverId: sectionIds[s.id] ?? s.serverId,
          ),
      ];
      questions = [
        for (final q in questions)
          ConsultationQuestion(
            id: q.id,
            text: q.text,
            selected: q.selected,
            serverId: questionIds[q.id] ?? q.serverId,
          ),
      ];
      reviewed = false;
    }
  }

  Future<void> saveDraft({
    String intent = 'edit',
    String? organizationSourceText,
  }) {
    _autosave?.cancel();
    return _serialize(() async {
      if (_disposed) return;
      if (conflict) throw ConflictException(code: 'revision_conflict');
      if (!_dirty && intent == 'edit') {
        if (saveError != null) {
          await preparation.refreshOverview();
          saveError = null;
          notifyListeners();
        }
        return;
      }
      final sent = _snapshot(), editVersion = _revision;
      saving = true;
      saveError = null;
      notifyListeners();
      try {
        var saved = await preparation.repository.writeReport(
          sent,
          intent: intent,
          organizationSourceText: organizationSourceText,
        );
        if (_clearRequested) {
          saved = await preparation.repository.clearReportSummary(
            sent.appointmentId,
            saved.contentRevision,
          );
          _clearRequested = false;
        }
        _accept(saved, sent, editVersion);
        await preparation.refreshOverview();
      } catch (e) {
        if (!_disposed && sent.appointmentId == _appointmentId) {
          saveError = e;
          if (e is ConflictException) {
            conflict = true;
            preservedDraft = _snapshot();
            _autosave?.cancel();
          }
        }
        rethrow;
      } finally {
        if (!_disposed) {
          saving = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> reloadLatest() => _serialize(() async {
    _autosave?.cancel();
    preservedDraft = _snapshot();
    try {
      final canonical = await preparation.repository.loadReport(
        _appointmentId!,
      );
      if (_disposed) return;
      _hydrate(
        canonical ??
            PreVisitReport(
              appointmentId: _appointmentId!,
              originalText: '',
              updatedAt: DateTime.now(),
            ),
      );
      _dirty = false;
      _clearRequested = false;
      conflict = false;
      saveError = null;
      _revision++;
      notifyListeners();
      await preparation.refreshOverview();
    } catch (e) {
      if (!_disposed) {
        saveError = e;
        notifyListeners();
      }
    }
  });
  void restorePreservedDraft() {
    final draft = preservedDraft;
    if (draft == null ||
        draft.appointmentId != _appointmentId ||
        conflict ||
        saving) {
      return;
    }
    text = draft.originalText;
    sections = [
      for (final s in draft.sections)
        ReportSection(
          id: s.id,
          sectionKey: s.sectionKey,
          title: s.title,
          text: s.text,
        ),
    ];
    questions = [
      for (final q in draft.questions)
        ConsultationQuestion(id: q.id, text: q.text, selected: q.selected),
    ];
    processedText = '\u0000';
    reviewed = false;
    _dirty = true;
    _revision++;
    preparation.invalidateFinalReview();
    notifyListeners();
  }

  void flushPendingEdits() {
    if (autosaveDelay != null && _dirty && !conflict) {
      saveDraft().catchError((Object _) {});
    }
  }

  void setText(String value) {
    if (text == value) return;
    text = value;
    _markChanged();
    failed = false;
    organizationError = null;
    notifyListeners();
  }

  Future<bool> organize() async {
    if (processing || text.trim().isEmpty) return false;
    final generation = ++_generation;
    final source = text;
    processing = true;
    failed = false;
    notifyListeners();
    try {
      final result = await assistant.organize(
        source,
        appointmentId: _appointmentId,
      );
      if (_disposed || generation != _generation) return false;
      if (text != source) {
        processing = false;
        notifyListeners();
        return false;
      }
      sections = result.sections;
      questions = result.questions;
      processedText = source;
      _generatedSourceHash = result.sourceHash;
      _markChanged();
      await saveDraft(intent: 'organize', organizationSourceText: source);
      if (_disposed || generation != _generation) return false;
      processing = false;
      notifyListeners();
      return true;
    } catch (error) {
      if (_disposed || generation != _generation) return false;
      processing = false;
      failed = true;
      organizationError = error;
      notifyListeners();
      return false;
    }
  }

  void cancelProcessing({bool notify = true}) {
    _generation++;
    processing = false;
    if (notify) notifyListeners();
  }

  void editSection(String id, String value) {
    if (!sections.any((section) => section.id == id && section.text != value)) {
      return;
    }
    sections = List.unmodifiable([
      for (final section in sections)
        section.id == id ? section.withText(value) : section,
    ]);
    _markChanged();
    notifyListeners();
  }

  void clearSummary() {
    sections = List.unmodifiable([
      for (final section in sections) section.withText(''),
    ]);
    questions = const [];
    _markChanged();
    _clearRequested = true;
    notifyListeners();
  }

  void selectQuestion(String id, bool selected) {
    if (!questions.any(
      (question) => question.id == id && question.selected != selected,
    )) {
      return;
    }
    questions = List.unmodifiable([
      for (final question in questions)
        question.id == id ? question.copyWith(selected: selected) : question,
    ]);
    _markChanged();
    notifyListeners();
  }

  void selectAll(bool selected) {
    if (questions.every((question) => question.selected == selected)) return;
    questions = List.unmodifiable([
      for (final question in questions) question.copyWith(selected: selected),
    ]);
    _markChanged();
    notifyListeners();
  }

  void saveQuestion(String text, {String? id}) {
    if (text.trim().isEmpty) return;
    if (id != null &&
        !questions.any(
          (question) => question.id == id && question.text != text.trim(),
        )) {
      return;
    }
    questions = List.unmodifiable([
      for (final question in questions)
        question.id == id ? question.copyWith(text: text.trim()) : question,
      if (id == null)
        ConsultationQuestion(
          id: 'custom-${++_questionSequence}',
          text: text.trim(),
        ),
    ]);
    _markChanged();
    notifyListeners();
  }

  void removeQuestion(String id) {
    if (!questions.any((question) => question.id == id)) return;
    questions = List.unmodifiable(
      questions.where((question) => question.id != id),
    );
    _markChanged();
    notifyListeners();
  }

  void moveQuestion(String id, int direction) {
    final items = questions.toList();
    final index = items.indexWhere((question) => question.id == id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= items.length) return;
    items.insert(target, items.removeAt(index));
    questions = List.unmodifiable(items);
    _markChanged();
    notifyListeners();
  }

  void dismissSuggestions() {
    showSuggestions = false;
    notifyListeners();
  }

  Future<void> startAudio() async {
    if (_disposed ||
        audioBusy ||
        audioStatus == AudioDraftStatus.transcribing ||
        audioStatus == AudioDraftStatus.recording ||
        audioStatus == AudioDraftStatus.paused) {
      return;
    }
    final generation = ++_audioGeneration;
    audioBusy = true;
    audioError = null;
    notifyListeners();
    try {
      if (capture != null && !await capture!.start()) {
        if (_disposed || generation != _audioGeneration) return;
        audioStatus = AudioDraftStatus.permissionDenied;
        audioError = const ApiException(
          'Não foi possível acessar o microfone. Você pode liberar a permissão nas configurações do navegador/dispositivo ou continuar digitando seu relato.',
          code: 'microphone_denied',
        );
        return;
      }
      if (_disposed || generation != _audioGeneration) return;
      seconds = 0;
      transcription = '';
      audioStatus = AudioDraftStatus.recording;
      _startTimer();
    } catch (_) {
      if (!_disposed && generation == _audioGeneration) {
        audioStatus = AudioDraftStatus.error;
        audioError = const ApiException(
          'Não foi possível iniciar o microfone. Você pode continuar digitando seu relato.',
          code: 'microphone_unavailable',
        );
      }
    } finally {
      if (!_disposed && generation == _audioGeneration) {
        audioBusy = false;
        notifyListeners();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      seconds++;
      notifyListeners();
      if (seconds >= audioMaxSeconds) {
        _timer?.cancel();
        unawaited(finishAudio().catchError((Object _) {}));
      }
    });
  }

  Future<void> toggleAudio() async {
    if (_disposed || audioBusy) return;
    final generation = _audioGeneration;
    audioBusy = true;
    try {
      if (audioStatus == AudioDraftStatus.recording) {
        _timer?.cancel();
        if (capture != null) await capture!.pause();
        if (_disposed || generation != _audioGeneration) return;
        audioStatus = AudioDraftStatus.paused;
      } else if (audioStatus == AudioDraftStatus.paused) {
        if (capture != null) await capture!.resume();
        if (_disposed || generation != _audioGeneration) return;
        audioStatus = AudioDraftStatus.recording;
        _startTimer();
      } else {
        return;
      }
    } catch (_) {
      if (!_disposed && generation == _audioGeneration) {
        audioError = const ApiException(
          'Não foi possível pausar ou continuar. Recomece a gravação ou continue digitando.',
          code: 'audio_invalid',
        );
        await cancelAudio();
      }
    } finally {
      if (!_disposed && generation == _audioGeneration) {
        audioBusy = false;
        notifyListeners();
      }
    }
  }

  void pauseAudio() {
    if (audioStatus == AudioDraftStatus.recording) unawaited(toggleAudio());
  }

  void leaveAudio() {
    if (realAudio &&
        (audioBusy ||
            audioStatus == AudioDraftStatus.recording ||
            audioStatus == AudioDraftStatus.paused ||
            audioStatus == AudioDraftStatus.transcribing)) {
      unawaited(cancelAudio());
    } else {
      pauseAudio();
    }
  }

  Future<void> cancelAudio({bool notify = true}) async {
    _audioGeneration++;
    _timer?.cancel();
    audioBusy = false;
    audioStatus = AudioDraftStatus.idle;
    if (notify && !_disposed) notifyListeners();
    try {
      await capture?.cancel();
    } catch (_) {
      /* Encerramento sem expor erro nativo. */
    }
  }

  Future<void> finishAudio() async {
    if (_disposed ||
        audioBusy ||
        (audioStatus != AudioDraftStatus.recording &&
            audioStatus != AudioDraftStatus.paused)) {
      return;
    }
    final generation = _audioGeneration;
    RecordedAudio? recording;
    _timer?.cancel();
    audioStatus = AudioDraftStatus.transcribing;
    notifyListeners();
    try {
      recording = await capture?.stop();
      if (_disposed || generation != _audioGeneration) return;
      final result = await audio.transcribe(
        text,
        appointmentId: _appointmentId,
        recording: recording,
      );
      if (_disposed || generation != _audioGeneration) return;
      transcription = result;
      audioStatus = AudioDraftStatus.review;
    } catch (error) {
      if (_disposed || generation != _audioGeneration) return;
      audioError = error;
      audioStatus = realAudio
          ? AudioDraftStatus.error
          : AudioDraftStatus.paused;
      rethrow;
    } finally {
      recording?.clear();
      if (!_disposed && generation == _audioGeneration) notifyListeners();
    }
  }

  void setTranscription(String value) {
    transcription = value;
  }

  void useTranscription() {
    final value = transcription.trim();
    if (value.isEmpty) return;
    // A demo of the existing text must not duplicate it or overwrite the draft.
    final merged = text.trim().isEmpty
        ? value
        : text.trim() == value
        ? text
        : '$text\n\n$value';
    if (merged.length > 20000) {
      throw const ApiException(
        'O relato completo deve ter no máximo 20.000 caracteres. Revise o texto antes de continuar.',
        code: 'report_too_long',
      );
    }
    setText(merged);
    audioStatus = AudioDraftStatus.idle;
    notifyListeners();
  }

  Future<void> finishReview() async {
    if (!hasContent || summaryOutdated) {
      throw StateError('Revise o relato atualizado.');
    }
    final revision = _revision;
    await saveDraft();
    if (_disposed) return;
    if (revision != _revision) {
      throw StateError('O relato mudou durante a revisão.');
    }
    await _serialize(() async {
      final sent = _snapshot();
      try {
        final saved = await preparation.repository.reviewReport(
          sent.appointmentId,
          contentRevision,
        );
        _accept(saved, sent, revision);
      } catch (e) {
        if (!_disposed) {
          saveError = e;
          if (e is ConflictException) {
            conflict = true;
            preservedDraft = _snapshot();
          }
          notifyListeners();
        }
        rethrow;
      }
    });
    if (revision != _revision) {
      throw StateError('O relato mudou durante a revisão.');
    }
    await preparation.refreshOverview();
    reviewed = true;
    notifyListeners();
  }

  Future<void> completePreparation() async {
    final revision = _revision;
    await finishReview();
    if (_disposed) return;
    if (revision != _revision) {
      throw StateError('O relato mudou durante a revisão.');
    }
    try {
      await preparation.completeFinalReview(expectedRevision: contentRevision);
    } catch (e) {
      if (!_disposed) {
        saveError = e;
        if (e is ConflictException) {
          conflict = true;
          preservedDraft = _snapshot();
        }
        notifyListeners();
      }
      rethrow;
    }
    if (!_disposed && revision == _revision) {
      final saved = preparation.overview!.report;
      finalReviewRevision = saved.finalReviewRevision;
      finalReviewAt = saved.finalReviewAt;
    }
    if (!_disposed && revision != _revision) {
      preparation.invalidateFinalReview();
      throw StateError('O relato mudou durante a revisão.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _audioGeneration++;
    unawaited(
      capture?.dispose().catchError((Object _) {}) ?? Future<void>.value(),
    );
    _timer?.cancel();
    _autosave?.cancel();
    preparation.removeListener(_initialize);
    text = processedText = transcription = '';
    sections = const [];
    questions = const [];
    _clarifications = const [];
    preservedDraft = null;
    saveError = null;
    _dirty = false;
    _appointmentId = null;
    super.dispose();
  }
}
