import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'tts_provider.dart';

class OpenAITtsProvider implements TtsProviderAdapter {
  static const _apiUrl = 'https://api.openai.com/v1/audio/speech';

  @override
  String get name => 'OpenAI';

  @override
  Map<String, String> get availableVoices => const {
        'alloy': 'Alloy — neutral, balanced',
        'echo': 'Echo — male, warm',
        'fable': 'Fable — male, narrative',
        'onyx': 'Onyx — male, deep',
        'nova': 'Nova — female, friendly',
        'shimmer': 'Shimmer — female, soft',
      };

  @override
  Future<List<int>> speak({required String text, required String voice}) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty) throw Exception('OPENAI_API_KEY is not set');

    // TTS API limit is ~4096 chars
    final input = text.length > 4000 ? text.substring(0, 4000) : text;

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'tts-1',
            'input': input,
            'voice': voice,
            'response_format': 'mp3',
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI TTS error ${response.statusCode}: ${response.body}');
    }

    return response.bodyBytes;
  }
}
