import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'tts_provider.dart';

class ElevenLabsTtsProvider implements TtsProviderAdapter {
  @override
  String get name => 'ElevenLabs';

  @override
  Map<String, String> get availableVoices => const {
        '21m00Tcm4TlvDq8ikWAM': 'Rachel — female, calm',
        '29vD33N1CtxCmqQRPOHJ': 'Drew — male, confident',
        'EXAVITQu4vr4xnSDxMaL': 'Sarah — female, soft',
        'ErXwobaYiN019PkySvjV': 'Antoni — male, warm',
        'MF3mGyEYCl7XYWbV9V6O': 'Elli — female, young',
        'TxGEqnHWrfWFTfGW9XjX': 'Josh — male, deep',
      };

  @override
  Future<List<int>> speak({required String text, required String voice}) async {
    final apiKey = dotenv.env['ELEVENLABS_API_KEY'] ?? '';
    if (apiKey.isEmpty) throw Exception('ELEVENLABS_API_KEY is not set');

    // ElevenLabs limit is ~5000 chars
    final input = text.length > 5000 ? text.substring(0, 5000) : text;

    final response = await http
        .post(
          Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voice'),
          headers: {
            'xi-api-key': apiKey,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': input,
            'model_id': 'eleven_multilingual_v2',
          }),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw Exception(
          'ElevenLabs TTS error ${response.statusCode}: ${response.body}');
    }

    return response.bodyBytes;
  }
}
