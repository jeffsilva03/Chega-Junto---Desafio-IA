import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:chega_junto_app/core/services/record_audio_capture_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android native PCM capture starts pauses resumes and stops', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Teste fictício de captura V8')),
      ),
    );
    final capture = RecordAudioCaptureService();
    addTearDown(capture.dispose);
    expect(await capture.start(), true);
    await Future<void>.delayed(const Duration(seconds: 2));
    await capture.pause();
    await capture.resume();
    await Future<void>.delayed(const Duration(seconds: 2));
    final audio = await capture.stop();
    expect(audio.bytes.length, greaterThan(44));
    final header = ByteData.sublistView(audio.bytes);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(22, Endian.little), 1);
    audio.clear();
    expect(audio.bytes, isEmpty);
  });
}
