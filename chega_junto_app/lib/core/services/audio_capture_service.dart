import 'dart:typed_data';

const audioMaxBytes = 10 * 1024 * 1024;
const audioMaxSeconds = 300;

class RecordedAudio {
  RecordedAudio(this.bytes);
  Uint8List bytes;
  void clear() {
    bytes.fillRange(0, bytes.length, 0);
    bytes = Uint8List(0);
  }
}

abstract interface class AudioCaptureService {
  Future<bool> start();
  Future<void> pause();
  Future<void> resume();
  Future<RecordedAudio> stop();
  Future<void> cancel();
  Future<void> dispose();
}

Uint8List pcmToWav(Uint8List pcm) {
  final bytes = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(bytes);
  void tag(int offset, String value) {
    bytes.setRange(offset, offset + value.length, value.codeUnits);
  }

  tag(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  bytes.setRange(44, bytes.length, pcm);
  return bytes;
}
