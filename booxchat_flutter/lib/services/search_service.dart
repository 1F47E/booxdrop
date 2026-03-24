import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SearchService {
  static const _apiUrl = 'https://api.perplexity.ai/chat/completions';

  static Future<String> search(String query) async {
    final apiKey = dotenv.env['PERPLEXITY_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'pplx-placeholder') {
      return 'Search unavailable: Perplexity API key not configured.';
    }

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'sonar',
              'messages': [
                {'role': 'user', 'content': query},
              ],
              'return_citations': true,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return 'Search failed (HTTP ${response.statusCode})';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      final content = choices.first['message']['content'] as String;

      // Append citations if present
      final citations = data['citations'] as List?;
      if (citations != null && citations.isNotEmpty) {
        final citationText = citations
            .asMap()
            .entries
            .map((e) => '[${e.key + 1}] ${e.value}')
            .join('\n');
        return '$content\n\nSources:\n$citationText';
      }

      return content;
    } catch (e) {
      return 'Search failed: $e';
    }
  }

  static Future<String> fetchPage(String url) async {
    try {
      final uri = Uri.parse(url);
      final resp = await http.get(uri, headers: {
        'User-Agent': 'BooxChat/1.0',
      }).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        return 'Failed to fetch page: HTTP ${resp.statusCode}';
      }

      // Strip HTML tags, collapse whitespace
      var text = resp.body
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Truncate to ~4000 chars for the model context
      if (text.length > 4000) {
        text = '${text.substring(0, 4000)}... [truncated]';
      }
      return text;
    } catch (e) {
      return 'Failed to fetch page: $e';
    }
  }
}
