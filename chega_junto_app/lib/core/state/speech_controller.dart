import 'package:flutter/foundation.dart';
import '../services/speech_engine.dart';
import '../services/device_speech.dart'
    if (dart.library.js_interop) '../services/browser_speech.dart'
    as platform;

class SpeechController extends ChangeNotifier {
  SpeechController([SpeechEngine? engine]) : _engine = engine;
  SpeechEngine? _engine;
  bool speaking = false, _disposed = false;
  int _generation = 0;
  String? error;
  Future<void> speak(String text) async {
    await stop();
    if (_disposed) return;
    final generation = ++_generation;
    error = null;
    speaking = true;
    notifyListeners();
    try {
      await (_engine ??= platform.createSpeechEngine()).speak(text);
    } catch (_) {
      if (!_disposed && generation == _generation) {
        error =
            'Não foi possível ler. Verifique se há uma voz em português instalada no aparelho.';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        speaking = false;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    _generation++;
    speaking = false;
    try {
      await _engine?.stop();
    } catch (_) {
      /* A leitura pode não estar disponível no dispositivo. */
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _engine?.stop().catchError((Object _) {});
    super.dispose();
  }
}
