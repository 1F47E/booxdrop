import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class OpenAIService {
  static const _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const model = 'gpt-4o';

  static Future<String> sendMessages(List<Message> messages) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages
                .map((m) => {'role': m.role, 'content': m.content})
                .toList(),
            'temperature': 0.7,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception(
          'OpenAI error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        (data['choices'] as List).first['message']['content'] as String;
    return content.trim();
  }
}
