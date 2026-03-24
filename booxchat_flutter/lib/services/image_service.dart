import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ImageService {
  static const _apiUrl = 'https://api.openai.com/v1/images/generations';

  /// Generates an image using gpt-image-1, returns raw base64 data.
  static Future<String> generateImage({
    required String prompt,
    String size = '1024x1024',
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

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
            'size': size,
            'quality': 'low',
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
          'Image generation error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final b64 = (data['data'] as List).first['b64_json'] as String;
    return b64;
  }
}
