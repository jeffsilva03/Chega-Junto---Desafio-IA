import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chega_junto_app/core/auth/auth_token_store.dart';
import 'package:chega_junto_app/core/network/api_client.dart';
import 'package:chega_junto_app/core/network/api_exception.dart';
import 'package:chega_junto_app/core/services/audio_capture_service.dart';
import 'package:chega_junto_app/core/services/audio_draft_service.dart';
import 'package:chega_junto_app/core/state/preparation_controller.dart';
import 'package:chega_junto_app/core/state/report_controller.dart';
import 'package:chega_junto_app/data/api/api_ai_assistant_service.dart';
import 'package:chega_junto_app/data/api/api_audio_draft_service.dart';
import 'package:chega_junto_app/data/mock/mock_ai_assistant_service.dart';
import 'package:chega_junto_app/data/mock/mock_preparation_repository.dart';

class FakeCapture implements AudioCaptureService {
  bool granted = true;
  int starts = 0, pauses = 0, resumes = 0, stops = 0, cancels = 0, disposes = 0;
  RecordedAudio? last;
  @override
  Future<bool> start() async {
    starts++;
    return granted;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<RecordedAudio> stop() async {
    stops++;
    return last = RecordedAudio(pcmToWav(Uint8List(320)));
  }

  @override
  Future<void> cancel() async {
    cancels++;
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }
}

class FakeTranscription implements AudioDraftService {
  int calls = 0;
  Object? error;
  Completer<String>? gate;
  @override
  Future<String> transcribe(
    String existingText, {
    String? appointmentId,
    RecordedAudio? recording,
  }) async {
    calls++;
    expectSync(appointmentId, isNotNull);
    expectSync(recording?.bytes, isNotEmpty);
    if (error != null) throw error!;
    return gate != null ? await gate!.future : 'Texto fictício transcrito.';
  }
}

void main() {
  late PreparationController preparation;
  late ReportController report;
  late FakeCapture capture;
  late FakeTranscription transcription;
  setUp(() async {
    preparation = PreparationController(MockPreparationRepository());
    await preparation.load();
    capture = FakeCapture();
    transcription = FakeTranscription();
    report = ReportController(
      preparation,
      const MockAiAssistantService(delay: Duration.zero),
      transcription,
      capture: capture,
    );
  });
  tearDown(() {
    report.dispose();
    preparation.dispose();
  });

  test(
    'API organization sends only original text to FastAPI and deselects questions',
    () async {
      final store = MemoryAuthTokenStore();
      await store.write('fictitious-token');
      var calls = 0;
      final client = ApiClient(
        'https://example.test',
        tokenStore: store,
        transport: MockClient((request) async {
          calls++;
          expect(
            request.url.path,
            '/api/v1/appointments/17/report/organization',
          );
          expect(request.headers['Authorization'], 'Bearer fictitious-token');
          expect(jsonDecode(request.body), {
            'original_text': 'Somente relato fictício',
          });
          return http.Response(
            jsonEncode({
              'sections': [
                {
                  'section_key': 'reason',
                  'title': 'Motivo da consulta',
                  'text': 'Texto',
                },
              ],
              'questions': [
                {'text': 'O que conversar?', 'is_selected': false},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      final result = await ApiAiAssistantService(
        client,
      ).organize('Somente relato fictício', appointmentId: '17');
      expect(result.sections.single.sectionKey, 'reason');
      expect(result.questions.single.selected, false);
      expect(calls, 1);
    },
  );

  for (final code in [
    'ai_daily_limit_reached',
    'ai_unavailable',
    'ai_invalid_output',
  ]) {
    test('API $code is sanitized and never automatically retried', () async {
      var calls = 0;
      final client = ApiClient(
        'https://example.test',
        transport: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'error': {'code': code, 'message': 'raw provider information'},
            }),
            code == 'ai_daily_limit_reached' ? 429 : 503,
          );
        }),
      );
      addTearDown(client.close);
      final service = ApiAiAssistantService(client);
      await expectLater(
        service.organize('Texto fictício', appointmentId: '1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.message.contains('raw'), 'sanitized', false),
        ),
      );
      expect(calls, 1);
      await expectLater(
        service.organize('Texto fictício', appointmentId: '1'),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 2);
    });
  }

  test('WAV multipart sends only recording, not existing report', () async {
    final client = ApiClient(
      'https://example.test',
      transport: MockClient((request) async {
        expect(request.url.path, '/api/v1/appointments/1/report/transcription');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        final envelope = latin1.decode(request.bodyBytes);
        expect(envelope, contains('name="file"; filename="recording.wav"'));
        expect(envelope, contains('audio/wav'));
        expect(envelope, isNot(contains('private existing text')));
        return http.Response(
          jsonEncode({'text': 'Texto para revisão.'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(client.close);
    final result = await ApiAudioDraftService(client).transcribe(
      'private existing text',
      appointmentId: '1',
      recording: RecordedAudio(pcmToWav(Uint8List(32))),
    );
    expect(result, 'Texto para revisão.');
  });

  test('10 MiB client limit rejects without upload', () async {
    var calls = 0;
    final client = ApiClient(
      'https://example.test',
      transport: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    await expectLater(
      ApiAudioDraftService(client).transcribe(
        '',
        appointmentId: '1',
        recording: RecordedAudio(Uint8List(audioMaxBytes + 1)),
      ),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'audio_too_large'),
      ),
    );
    expect(calls, 0);
  });

  test(
    'permission requested on start only, denial preserves typed report',
    () async {
      report.setText('Relato fictício já digitado');
      capture.granted = false;
      expect(capture.starts, 0);
      await report.startAudio();
      expect(capture.starts, 1);
      expect(report.audioStatus, AudioDraftStatus.permissionDenied);
      expect(report.text, 'Relato fictício já digitado');
      expect(transcription.calls, 0);
      capture.granted = true;
      await report.startAudio();
      expect(report.audioStatus, AudioDraftStatus.recording);
    },
  );

  test(
    'real capture pause resume stop review edit explicit use and memory cleanup',
    () async {
      report.setText('Original fictício');
      await report.startAudio();
      await report.toggleAudio();
      expect(report.audioStatus, AudioDraftStatus.paused);
      await report.toggleAudio();
      expect(report.audioStatus, AudioDraftStatus.recording);
      expect(capture.pauses, 1);
      expect(capture.resumes, 1);
      await report.finishAudio();
      expect(capture.stops, 1);
      expect(report.audioStatus, AudioDraftStatus.review);
      expect(report.text, 'Original fictício');
      expect(capture.last!.bytes, isEmpty);
      report.setTranscription('Texto revisado');
      report.useTranscription();
      expect(report.text, 'Original fictício\n\nTexto revisado');
    },
  );

  test('transcription cannot start twice or restore after cancel', () async {
    transcription.gate = Completer<String>();
    await report.startAudio();
    final pending = report.finishAudio();
    await Future<void>.delayed(Duration.zero);
    expect(report.audioStatus, AudioDraftStatus.transcribing);
    await report.startAudio();
    await report.finishAudio();
    expect(capture.starts, 1);
    expect(transcription.calls, 1);
    await report.cancelAudio();
    transcription.gate!.complete('Old result');
    await pending;
    expect(report.audioStatus, AudioDraftStatus.idle);
    expect(report.transcription, isEmpty);
  });

  test(
    'transcription failure preserves original and requires new recording',
    () async {
      report.setText('Original fictício');
      transcription.error = const ApiException(
        'IA indisponível',
        code: 'ai_unavailable',
      );
      await report.startAudio();
      await expectLater(report.finishAudio(), throwsA(isA<ApiException>()));
      expect(report.audioStatus, AudioDraftStatus.error);
      expect(report.text, 'Original fictício');
      expect(capture.last!.bytes, isEmpty);
      expect(transcription.calls, 1);
    },
  );

  test('leaving the audio route closes microphone', () async {
    await report.startAudio();
    report.leaveAudio();
    await Future<void>.delayed(Duration.zero);
    expect(capture.cancels, 1);
    expect(report.audioStatus, AudioDraftStatus.idle);
  });

  test('combined transcript limit preserves both drafts', () {
    report.setText('x' * 19999);
    report.setTranscription('new text');
    expect(report.useTranscription, throwsA(isA<ApiException>()));
    expect(report.text.length, 19999);
    expect(report.transcription, 'new text');
  });

  testWidgets('five-minute cap stops once and produces review', (tester) async {
    await report.startAudio();
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(report.seconds, 300);
    expect(capture.stops, 1);
    expect(transcription.calls, 1);
    expect(report.audioError, isNull);
    expect(report.audioStatus, AudioDraftStatus.review);
    await tester.pump(const Duration(seconds: 10));
    expect(capture.stops, 1);
  });

  test('WAV header is mono PCM16 16 kHz and bounded for five minutes', () {
    final wav = pcmToWav(Uint8List(16000 * 2 * 300));
    final header = ByteData.sublistView(wav);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint16(34, Endian.little), 16);
    expect(wav.length, lessThan(audioMaxBytes));
  });

  test(
    'logout disposal rejects late transcription and does not affect another account',
    () async {
      final oldCapture = FakeCapture();
      final oldAudio = FakeTranscription()..gate = Completer<String>();
      final old = ReportController(
        preparation,
        const MockAiAssistantService(),
        oldAudio,
        capture: oldCapture,
      );
      await old.startAudio();
      final pending = old.finishAudio();
      await Future<void>.delayed(Duration.zero);
      old.dispose();
      report.setText('Rascunho da outra sessão');
      oldAudio.gate!.complete('Resultado da sessão anterior');
      await pending;
      expect(old.transcription, isEmpty);
      expect(old.text, isEmpty);
      expect(oldCapture.disposes, 1);
      expect(oldCapture.last!.bytes, isEmpty);
      expect(report.text, 'Rascunho da outra sessão');
      expect(report.transcription, isEmpty);
    },
  );
}
