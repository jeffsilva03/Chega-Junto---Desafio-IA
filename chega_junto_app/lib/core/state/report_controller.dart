import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/organized_report.dart';
import '../services/ai_assistant_service.dart';
import '../services/audio_draft_service.dart';
import 'preparation_controller.dart';

enum AudioDraftStatus { idle, recording, paused, transcribing, review }

/// One draft per appointment, kept outside routes for the lifetime of the session.
class ReportController extends ChangeNotifier {
  ReportController(this.preparation, this.assistant, this.audio) {
    preparation.addListener(_initialize);
    _initialize();
  }
  final PreparationController preparation;
  final AiAssistantService assistant;
  final AudioDraftService audio;
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
  int _generation = 0, _questionSequence = 0;
  Timer? _timer;
  bool get hasSummary => sections.isNotEmpty;
  bool get summaryOutdated => hasSummary && processedText != text;
  bool get hasContent =>
      sections.any((section) => section.text.trim().isNotEmpty);
  String get clock =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  void _initialize() {
    if (_initialized || preparation.overview == null) return;
    _initialized = true;
    text = preparation.overview!.report.originalText;
    notifyListeners();
  }

  void setText(String value) {
    if (text == value) return;
    text = value;
    reviewed = false;
    failed = false;
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
      final result = await assistant.organize(source);
      if (_disposed || generation != _generation) return false;
      sections = result.sections;
      questions = result.questions;
      processedText = source;
      reviewed = false;
      processing = false;
      notifyListeners();
      return true;
    } catch (_) {
      if (_disposed || generation != _generation) return false;
      processing = false;
      failed = true;
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
    sections = List.unmodifiable([
      for (final section in sections)
        section.id == id ? section.withText(value) : section,
    ]);
    reviewed = false;
    notifyListeners();
  }

  void clearSummary() {
    sections = List.unmodifiable([
      for (final section in sections) section.withText(''),
    ]);
    questions = const [];
    reviewed = false;
    notifyListeners();
  }

  void selectQuestion(String id, bool selected) {
    questions = List.unmodifiable([
      for (final question in questions)
        question.id == id ? question.copyWith(selected: selected) : question,
    ]);
    reviewed = false;
    notifyListeners();
  }

  void selectAll(bool selected) {
    questions = List.unmodifiable([
      for (final question in questions) question.copyWith(selected: selected),
    ]);
    reviewed = false;
    notifyListeners();
  }

  void saveQuestion(String text, {String? id}) {
    if (text.trim().isEmpty) return;
    questions = List.unmodifiable([
      for (final question in questions)
        question.id == id ? question.copyWith(text: text.trim()) : question,
      if (id == null)
        ConsultationQuestion(
          id: 'custom-${++_questionSequence}',
          text: text.trim(),
        ),
    ]);
    reviewed = false;
    notifyListeners();
  }

  void removeQuestion(String id) {
    questions = List.unmodifiable(
      questions.where((question) => question.id != id),
    );
    reviewed = false;
    notifyListeners();
  }

  void moveQuestion(String id, int direction) {
    final items = questions.toList();
    final index = items.indexWhere((question) => question.id == id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= items.length) return;
    items.insert(target, items.removeAt(index));
    questions = List.unmodifiable(items);
    reviewed = false;
    notifyListeners();
  }

  void dismissSuggestions() {
    showSuggestions = false;
    notifyListeners();
  }

  void startAudio() {
    if (audioStatus == AudioDraftStatus.transcribing) return;
    seconds = 0;
    transcription = '';
    audioStatus = AudioDraftStatus.recording;
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      seconds++;
      notifyListeners();
    });
  }

  void toggleAudio() {
    if (audioStatus == AudioDraftStatus.recording) {
      _timer?.cancel();
      audioStatus = AudioDraftStatus.paused;
    } else if (audioStatus == AudioDraftStatus.paused) {
      audioStatus = AudioDraftStatus.recording;
      _startTimer();
    } else {
      return;
    }
    notifyListeners();
  }

  void pauseAudio() {
    if (audioStatus == AudioDraftStatus.recording) toggleAudio();
  }

  Future<void> finishAudio() async {
    if (audioStatus != AudioDraftStatus.recording &&
        audioStatus != AudioDraftStatus.paused) {
      return;
    }
    _timer?.cancel();
    audioStatus = AudioDraftStatus.transcribing;
    notifyListeners();
    try {
      final result = await audio.transcribeDemo(text);
      if (_disposed) return;
      transcription = result;
      audioStatus = AudioDraftStatus.review;
    } catch (_) {
      if (_disposed) return;
      audioStatus = AudioDraftStatus.paused;
      rethrow;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void setTranscription(String value) {
    transcription = value;
  }

  void useTranscription() {
    final value = transcription.trim();
    if (value.isEmpty) return;
    // A demo of the existing text must not duplicate it or overwrite the draft.
    setText(
      text.trim().isEmpty
          ? value
          : text.trim() == value
          ? text
          : '$text\n\n$value',
    );
    audioStatus = AudioDraftStatus.idle;
    notifyListeners();
  }

  Future<void> finishReview() async {
    if (!hasContent || summaryOutdated) {
      throw StateError('Revise o relato atualizado.');
    }
    await preparation.saveReportReview(text, sections, questions);
    if (_disposed) return;
    reviewed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    preparation.removeListener(_initialize);
    super.dispose();
  }
}
