import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'image_provider.dart';
import 'log_service.dart';

final _log = LogService.instance;

class NanoBananaProvider implements ImageProviderAdapter {
  final String model;

  NanoBananaProvider({this.model = 'gemini-3.1-flash-image-preview'});

  @override
  String get name => 'Nano Banana';

  @override
  bool get supportsEdit => true;

  String get _apiKey => dotenv.env['GOOGLE_AI_API_KEY'] ?? '';

  Uri get _endpoint => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey');

  Map<String, dynamic> get _generationConfig => {
        'responseModalities': ['TEXT', 'IMAGE'],
        'imageConfig': {'imageSize': '1K'},
      };

  @override
  Future<String> generate({required String prompt}) async {
    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': _generationConfig,
    };

    return _sendRequest(body);
  }

  @override
  Future<String> edit(
      {required String imagePath, required String instruction}) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);

    final body = {
      'contents': [
        {
          'parts': [
            {
              'inlineData': {'mimeType': 'image/png', 'data': b64},
            },
            {'text': instruction},
          ],
        },
      ],
      'generationConfig': _generationConfig,
    };

    return _sendRequest(body);
  }

  Future<String> _sendRequest(Map<String, dynamic> body) async {
    if (_apiKey.isEmpty) {
      _log.error('image', 'GOOGLE_AI_API_KEY not set');
      throw Exception('GOOGLE_AI_API_KEY is not set');
    }
    _log.info('image', 'Nano Banana $model request...');
    final sw = Stopwatch()..start();
    final response = await http
        .post(
          _endpoint,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
    sw.stop();

    if (response.statusCode != 200) {
      _log.error('image', 'Nano Banana HTTP ${response.statusCode}');
      throw Exception(
          'Nano Banana error ${response.statusCode}: ${response.body}');
    }
    _log.debug('image', 'Nano Banana ${sw.elapsedMilliseconds}ms');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List;
    final parts =
        (candidates.first as Map<String, dynamic>)['content']['parts'] as List;

    for (final part in parts) {
      final p = part as Map<String, dynamic>;
      if (p.containsKey('inlineData')) {
        return p['inlineData']['data'] as String;
      }
    }

    throw Exception('No image data in Nano Banana response');
  }
}
