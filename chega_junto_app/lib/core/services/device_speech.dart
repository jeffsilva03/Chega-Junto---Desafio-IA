import 'package:flutter_tts/flutter_tts.dart';
import 'speech_engine.dart';

SpeechEngine createSpeechEngine() => _DeviceSpeech();

class _DeviceSpeech implements SpeechEngine {
  FlutterTts? _tts;
  int _generation = 0;
  Future<FlutterTts>? _initializing;
  Future<FlutterTts> _initialize() async {
    if (_tts != null) return _tts!;
    if (_initializing != null) return _initializing!;
    try {
      return await (_initializing = _configure());
    } finally {
      _initializing = null;
    }
  }

  Future<FlutterTts> _configure() async {
    final tts = FlutterTts();
    final voices =
        await tts.getVoices.timeout(const Duration(seconds: 10))
            as List<dynamic>;
    final local = voices
        .whereType<Map>()
        .where(
          (voice) =>
              '${voice['locale']}'
                  .toLowerCase()
                  .replaceAll('_', '-')
                  .startsWith('pt') &&
              (voice['network_required'] == false ||
                  voice['network_required'] == 'false' ||
                  voice['network_required'] == '0' ||
                  voice['network_required'] == 0),
        )
        .toList();
    if (local.isEmpty) throw StateError('local-voice-unavailable');
    local.sort(
      (a, b) =>
          ('${a['locale']}'.toLowerCase().replaceAll('_', '-') == 'pt-br'
                  ? 0
                  : 1)
              .compareTo(
                '${b['locale']}'.toLowerCase().replaceAll('_', '-') == 'pt-br'
                    ? 0
                    : 1,
              ),
    );
    await tts.setLanguage('${local.first['locale']}');
    await tts.setVoice({
      'name': '${local.first['name']}',
      'locale': '${local.first['locale']}',
    });
    await tts.setSpeechRate(.45);
    await tts.awaitSpeakCompletion(true);
    _tts = tts;
    return tts;
  }

  @override
  Future<void> speak(String text) async {
    final generation = ++_generation;
    final tts = await _initialize();
    if (generation == _generation) {
      final result = await tts.speak(text);
      if (result != 1) throw StateError('speech-unavailable');
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _tts?.stop();
  }
}
