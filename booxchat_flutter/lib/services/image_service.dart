import '../providers/settings_provider.dart';
import 'grok_image_provider.dart';
import 'image_provider.dart';
import 'nano_banana_provider.dart';
import 'openai_image_provider.dart';

class ImageService {
  static ImageProviderAdapter getProvider(SettingsProvider settings) {
    switch (settings.imageProvider) {
      case 'openai':
        return OpenAIImageProvider();
      case 'grok':
        return GrokImageProvider(model: settings.grokModel);
      case 'nano_banana':
      default:
        return NanoBananaProvider(model: settings.nanoBananaModel);
    }
  }
}
