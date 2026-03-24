import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchService {
  static Future<String> search(String query) async {
    // Tier 1: DuckDuckGo Instant Answer API
    try {
      final instantUrl = Uri.parse(
        'https://api.duckduckgo.com/?q=${Uri.encodeComponent(query)}&format=json&no_redirect=1',
      );
      final instantResp =
          await http.get(instantUrl).timeout(const Duration(seconds: 10));

      if (instantResp.statusCode == 200) {
        final data = jsonDecode(instantResp.body) as Map<String, dynamic>;

        // Check AbstractText first
        final abstractText = (data['AbstractText'] ?? '') as String;
        if (abstractText.isNotEmpty) return abstractText;

        // Parse RelatedTopics for snippets
        final related = data['RelatedTopics'] as List? ?? [];
        final snippets = <String>[];
        for (final topic in related) {
          if (topic is Map<String, dynamic>) {
            if (topic.containsKey('Text')) {
              snippets.add(topic['Text'] as String);
            } else if (topic.containsKey('Topics')) {
              for (final sub in (topic['Topics'] as List)) {
                if (sub is Map<String, dynamic> && sub.containsKey('Text')) {
                  snippets.add(sub['Text'] as String);
                }
                if (snippets.length >= 6) break;
              }
            }
          }
          if (snippets.length >= 6) break;
        }
        if (snippets.isNotEmpty) return snippets.join('\n\n');
      }
    } catch (_) {
      // Fall through to tier 2
    }

    // Tier 2: DuckDuckGo HTML search (scrape snippets)
    try {
      final htmlUrl = Uri.parse(
        'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}',
      );
      final htmlResp = await http.get(htmlUrl, headers: {
        'User-Agent': 'BooxChat/1.0',
      }).timeout(const Duration(seconds: 10));

      if (htmlResp.statusCode == 200) {
        final snippetPattern =
            RegExp(r'class="result__snippet"[^>]*>(.*?)</(?:a|span)', dotAll: true);
        final matches = snippetPattern.allMatches(htmlResp.body).take(5);
        final results = matches
            .map((m) =>
                m.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();

        if (results.isNotEmpty) return results.join('\n\n');
      }
    } catch (_) {
      // Fall through
    }

    return 'No search results found for: $query';
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
