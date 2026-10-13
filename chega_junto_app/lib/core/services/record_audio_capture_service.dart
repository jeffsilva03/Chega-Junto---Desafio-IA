import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import '../network/api_exception.dart';
import 'audio_capture_service.dart';

/// PCM mono 16 kHz: cinco minutos ficam abaixo de 10 MiB, inclusive header WAV.
/// Sem arquivo/blob temporário, conversor externo ou dependência de encoder AAC.
class RecordAudioCaptureService implements AudioCaptureService {
  RecordAudioCaptureService({AudioRecorder? recorder}) : _instance = recorder;
  AudioRecorder? _instance;
  AudioRecorder get _recorder => _instance ??= AudioRecorder();
  final _buffer = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  bool _disposed = false, _tooLarge = false;
  Object? _streamError;
  int _generation = 0;

  @override
  Future<bool> start() async {
    final generation = ++_generation;
    if (_disposed) return false;
    final granted = await _recorder.hasPermission();
    if (_disposed || generation != _generation || !granted) return false;
    _buffer.clear();
    _tooLarge = false;
    _streamError = null;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    if (_disposed || generation != _generation) {
      await _recorder.cancel();
      return false;
    }
    _subscription = stream.listen(
      (part) {
        if (_disposed || generation != _generation) return;
        if (_buffer.length + part.length + 44 > audioMaxBytes) {
          _tooLarge = true;
        } else if (!_tooLarge) {
          _buffer.add(part);
        }
      },
      onError: (Object error) {
        _streamError = const NetworkException();
      },
    );
    return true;
  }

  @override
  Future<void> pause() => _recorder.pause();
  @override
  Future<void> resume() => _recorder.resume();
  @override
  Future<RecordedAudio> stop() async {
    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
    if (_streamError != null) throw _streamError!;
    if (_tooLarge) {
      _buffer.clear();
      throw const ApiException(
        'O áudio deve ter no máximo 10 MB.',
        code: 'audio_too_large',
      );
    }
    final pcm = _buffer.takeBytes();
    if (pcm.isEmpty) {
      throw const ApiException(
        'Não foi possível gravar. Tente novamente.',
        code: 'audio_invalid',
      );
    }
    final result = RecordedAudio(pcmToWav(pcm));
    pcm.fillRange(0, pcm.length, 0);
    return result;
  }

  @override
  Future<void> cancel() async {
    _generation++;
    await _instance?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    final pcm = _buffer.takeBytes();
    pcm.fillRange(0, pcm.length, 0);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await cancel();
    } finally {
      await _instance?.dispose();
    }
  }
}
