import '../providers/settings_provider.dart';
import 'elevenlabs_tts_provider.dart';
import 'openai_tts_provider.dart';
import 'tts_provider.dart';

class TtsService {
  static TtsProviderAdapter getProvider(SettingsProvider settings) {
    switch (settings.ttsProvider) {
      case 'elevenlabs':
        return ElevenLabsTtsProvider();
      case 'openai':
      default:
        return OpenAITtsProvider();
    }
  }
}
