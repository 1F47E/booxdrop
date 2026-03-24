import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'image_provider.dart';

class OpenAIImageProvider implements ImageProviderAdapter {
  static const _apiUrl = 'https://api.openai.com/v1/images/generations';

  @override
  String get name => 'OpenAI';

  @override
  bool get supportsEdit => false;

  @override
  Future<String> generate({required String prompt}) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) throw Exception('OPENAI_API_KEY is not set');

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'gpt-image-1',
            'prompt': prompt,
            'n': 1,
            'size': '1024x1024',
            'quality': 'low',
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI image error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List).first['b64_json'] as String;
  }

  @override
  Future<String> edit(
      {required String imagePath, required String instruction}) async {
    throw UnsupportedError('OpenAI provider does not support image editing');
  }
}
