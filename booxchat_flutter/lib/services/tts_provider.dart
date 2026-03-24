/// Abstract adapter for text-to-speech providers.
abstract class TtsProviderAdapter {
  String get name;

  /// Map of voice ID → display label (e.g. "Nova — female, friendly").
  Map<String, String> get availableVoices;

  /// Generate speech audio from text. Returns raw mp3 bytes.
  Future<List<int>> speak({required String text, required String voice});
}
