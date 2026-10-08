abstract interface class SpeechEngine {
  Future<void> speak(String text);
  Future<void> stop();
}
