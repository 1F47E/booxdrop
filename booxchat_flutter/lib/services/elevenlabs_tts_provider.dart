import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'tts_provider.dart';

class ElevenLabsTtsProvider implements TtsProviderAdapter {
  @override
  String get name => 'ElevenLabs';

  @override
  Map<String, String> get availableVoices => const {
        '9BWtsMINqrJLrRacOk9x': 'Aria — female, expressive, engaging',
        'CwhRBWXzGAHq8TQ4Fs17': 'Roger — male, confident, persuasive',
        'EXAVITQu4vr4xnSDxMaL': 'Sarah — female, soft, expressive',
        'SAz9YHcvj6GT2YYXdXww': 'River — non-binary, confident, modern',
        'cjVigY5qzO86Huf0OWal': 'Eric — male, friendly, approachable',
        'cgSgspJ2msm6clMCkdW9': 'Jessica — female, youthful, conversational',
        'bIHbv24MWmeRgasZH58o': 'Will — male, warm, narrative',
        'FGY2WhTYpPnrIDTdsKH5': 'Laura — female, clear, narration',
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
