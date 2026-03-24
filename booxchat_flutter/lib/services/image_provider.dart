/// Abstract adapter for image generation/editing providers.
abstract class ImageProviderAdapter {
  String get name;
  bool get supportsEdit;

  /// Generate a new image from a text prompt. Returns base64 PNG data.
  Future<String> generate({required String prompt});

  /// Edit an existing image with a text instruction. Returns base64 PNG data.
  /// Throws [UnsupportedError] if the provider doesn't support editing.
  Future<String> edit({required String imagePath, required String instruction});
}
