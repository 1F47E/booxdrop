import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match_record.dart';

class HistoryService {
  static Future<List<MatchRecord>> fetchMatches(
    String baseUrl, {
    String? playerDeviceId,
    int limit = 50,
  }) async {
    var url = '$baseUrl/api/matches?limit=$limit';
    if (playerDeviceId != null) {
      url += '&player=$playerDeviceId';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load matches: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((m) => MatchRecord.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<MatchRecord?> fetchMatch(String baseUrl, String matchId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/matches/$matchId'));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to load match: ${response.statusCode}');
    }

    return MatchRecord.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
