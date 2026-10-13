import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/services/audio_capture_service.dart';
import '../../core/services/audio_draft_service.dart';

class ApiAudioDraftService implements AudioDraftService {
  const ApiAudioDraftService(this.client);
  final ApiClient client;
  @override
  Future<String> transcribe(
    String existingText, {
    String? appointmentId,
    RecordedAudio? recording,
  }) async {
    if (appointmentId == null || recording == null || recording.bytes.isEmpty) {
      throw const ApiException(
        'Grave um áudio antes de transcrever.',
        code: 'audio_invalid',
      );
    }
    if (recording.bytes.length > audioMaxBytes) {
      throw const ApiException(
        'O áudio deve ter no máximo 10 MB.',
        code: 'audio_too_large',
      );
    }
    final json = await client.request(
      'POST',
      '/api/v1/appointments/$appointmentId/report/transcription',
      audioBytes: recording.bytes,
      timeout: const Duration(seconds: 140),
    );
    final text = json['text'];
    if (text is! String || text.trim().isEmpty || text.length > 20000) {
      throw const ApiException(
        'Não foi possível transcrever. Faça uma gravação menor.',
        code: 'transcription_failed',
      );
    }
    return text;
  }
}
