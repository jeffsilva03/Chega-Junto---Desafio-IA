import 'audio_capture_service.dart';

abstract interface class AudioDraftService {
  Future<String> transcribe(
    String existingText, {
    String? appointmentId,
    RecordedAudio? recording,
  });
}
