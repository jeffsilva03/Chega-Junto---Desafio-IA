import '../../core/services/audio_draft_service.dart';
import '../../core/services/audio_capture_service.dart';

class MockAudioDraftService implements AudioDraftService {
  const MockAudioDraftService({this.delay = const Duration(milliseconds: 700)});
  final Duration delay;
  @override
  Future<String> transcribe(
    String existingText, {
    String? appointmentId,
    RecordedAudio? recording,
  }) async {
    await Future<void>.delayed(delay);
    // Existing user text is the demonstration's source. No microphone is used.
    return existingText.trim().isNotEmpty
        ? existingText
        : 'Quero organizar minhas dúvidas para conversar na consulta.';
  }
}
