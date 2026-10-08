import 'dart:async';
import 'dart:js_interop';
import 'speech_engine.dart';

@JS('window.speechSynthesis')
external _Synthesis get _synthesis;
extension type _Synthesis(JSObject _) implements JSObject {
  external JSArray<_Voice> getVoices();
  external void speak(_Utterance utterance);
  external void cancel();
}
extension type _Voice(JSObject _) implements JSObject {
  external String get lang;
  external bool get localService;
}
@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external factory _Utterance(String text);
  external set voice(_Voice value);
  external set lang(String value);
  external set rate(double value);
  external set onend(JSFunction value);
  external set onerror(JSFunction value);
}

SpeechEngine createSpeechEngine() => _BrowserSpeech();

class _BrowserSpeech implements SpeechEngine {
  Completer<void>? _completion;
  _Utterance? _active;
  int _generation = 0;
  @override
  Future<void> speak(String text) async {
    final generation = ++_generation;
    for (
      var attempt = 0;
      _synthesis.getVoices().toDart.isEmpty && attempt < 20;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (generation != _generation) return;
    }
    final voices = _synthesis
        .getVoices()
        .toDart
        .where((v) => v.localService && v.lang.toLowerCase().startsWith('pt'))
        .toList();
    if (voices.isEmpty) throw StateError('local-voice-unavailable');
    voices.sort(
      (a, b) => (a.lang.toLowerCase() == 'pt-br' ? 0 : 1).compareTo(
        b.lang.toLowerCase() == 'pt-br' ? 0 : 1,
      ),
    );
    final completion = Completer<void>();
    _completion = completion;
    final utterance = _Utterance(text)
      ..voice = voices.first
      ..lang = voices.first.lang
      ..rate = .9;
    utterance.onend = ((JSAny? event) {
      if (!completion.isCompleted) completion.complete();
    }).toJS;
    utterance.onerror = ((JSAny? event) {
      if (!completion.isCompleted) {
        completion.completeError(StateError('speech-unavailable'));
      }
    }).toJS;
    _active = utterance;
    _synthesis.speak(_active!);
    try {
      await completion.future;
    } finally {
      if (generation == _generation) {
        _active = null;
        _completion = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _synthesis.cancel();
    _active = null;
    final completion = _completion;
    _completion = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }
}
