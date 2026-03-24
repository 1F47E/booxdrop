import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'image_provider.dart';
import 'log_service.dart';

final _log = LogService.instance;

class GrokImageProvider implements ImageProviderAdapter {
  static const _generateUrl = 'https://api.x.ai/v1/images/generations';
  static const _editUrl = 'https://api.x.ai/v1/images/edits';

  final String model;

  GrokImageProvider({this.model = 'grok-imagine-image'});

  @override
  String get name => 'Grok';

  @override
  bool get supportsEdit => true;

  String get _apiKey => dotenv.env['XAI_API_KEY'] ?? '';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  @override
  Future<String> generate({required String prompt}) async {
    if (_apiKey.isEmpty) {
      _log.error('image', 'XAI_API_KEY not set');
      throw Exception('XAI_API_KEY is not set');
    }
    _log.info('image', 'Grok $model generating...');
    final sw = Stopwatch()..start();

    final response = await http
        .post(
          Uri.parse(_generateUrl),
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'prompt': prompt,
            'n': 1,
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 120));
    sw.stop();

    if (response.statusCode != 200) {
      _log.error('image', 'Grok HTTP ${response.statusCode}');
      throw Exception(
          'Grok error ${response.statusCode}: ${response.body}');
    }
    _log.debug('image', 'Grok ${sw.elapsedMilliseconds}ms');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List).first['b64_json'] as String;
  }

  @override
  Future<String> edit(
      {required String imagePath, required String instruction}) async {
    if (_apiKey.isEmpty) {
      _log.error('image', 'XAI_API_KEY not set');
      throw Exception('XAI_API_KEY is not set');
    }
    _log.info('image', 'Grok $model editing...');
    final sw = Stopwatch()..start();

    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse(_editUrl),
          headers: _headers,
          body: jsonEncode({
            'model': model,
            'prompt': instruction,
            'image': {
              'url': 'data:image/png;base64,$b64',
              'type': 'image_url',
            },
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 120));
    sw.stop();

    if (response.statusCode != 200) {
      _log.error('image', 'Grok edit HTTP ${response.statusCode}');
      throw Exception(
          'Grok edit error ${response.statusCode}: ${response.body}');
    }
    _log.debug('image', 'Grok edit ${sw.elapsedMilliseconds}ms');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['data'] as List).first['b64_json'] as String;
  }
}
