import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'image_provider.dart';
import 'log_service.dart';

final _log = LogService.instance;

class OpenAIImageProvider implements ImageProviderAdapter {
  static const _apiUrl = 'https://api.openai.com/v1/images/generations';

  @override
  String get name => 'OpenAI';

  @override
  bool get supportsEdit => false;

  @override
  Future<String> generate({required String prompt}) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      _log.error('image', 'OPENAI_API_KEY not set');
      throw Exception('OPENAI_API_KEY is not set');
    }
    _log.info('image', 'OpenAI gpt-image-1 request...');
    final sw = Stopwatch()..start();
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

    sw.stop();
    if (response.statusCode != 200) {
      _log.error('image', 'OpenAI image HTTP ${response.statusCode}');
      throw Exception(
          'OpenAI image error ${response.statusCode}: ${response.body}');
    }
    _log.debug('image', 'OpenAI image ${sw.elapsedMilliseconds}ms');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List).first['b64_json'] as String;
  }

  @override
  Future<String> edit(
      {required String imagePath, required String instruction}) async {
    throw UnsupportedError('OpenAI provider does not support image editing');
  }
}
