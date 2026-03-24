import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/session.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import 'settings_provider.dart';

class ChatProvider extends ChangeNotifier {
  final SettingsProvider _settings;
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _currentSessionId;
  Session? _currentSession;
  List<Session> _sessions = [];
  Timer? _saveTimer;
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isOnline = true;
  String? _apiKeyWarning;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentSessionId => _currentSessionId;
  Session? get currentSession => _currentSession;
  List<Session> get sessions => List.unmodifiable(_sessions);
  bool get isOnline => _isOnline;
  String? get apiKeyWarning => _apiKeyWarning;

  ChatProvider(this._settings) {
    _connectivity.checkNow().then((online) {
      _isOnline = online;
      notifyListeners();
    });
    _connectivity.startListening((online) {
      _isOnline = online;
      notifyListeners();
    });
    _loadSessions();
    _validateApiKey();
  }

  Message _buildSystemPrompt() {
    final buf = StringBuffer();
    buf.writeln('You are a helpful assistant on a Boox e-ink tablet device.');
    buf.writeln();

    // Language mirroring (always active)
    buf.writeln('IMPORTANT: Always respond in the same language the user writes in. '
        'If the user writes in Spanish, respond in Spanish. '
        'If they write in Russian, respond in Russian. And so on.');
    buf.writeln();

    if (_settings.kidsMode) {
      final age = _settings.kidsAge;
      buf.writeln('The user is a child aged $age. Adjust your responses:');
      buf.writeln('- Use simple vocabulary appropriate for a $age-year-old.');
      if (age <= 6) {
        buf.writeln('- Keep answers very short: 1-3 sentences.');
        buf.writeln('- Use lots of emojis to make it fun and engaging.');
      } else {
        buf.writeln('- Keep answers short: 3-6 sentences.');
        buf.writeln('- Use emojis to make responses friendly.');
      }
      buf.writeln('- Be friendly, encouraging, and patient.');
      buf.writeln('- NEVER include violent, scary, sexual, or inappropriate content.');
      buf.writeln('- If asked about something inappropriate, gently redirect.');
      buf.writeln();
    }

    // Tool descriptions
    buf.writeln('You have access to the following tools:');
    buf.writeln('- web_search: Search the web for current information.');
    buf.writeln('- fetch_page: Fetch and read the content of a specific URL.');
    buf.writeln('- generate_image: Generate an image from a text description.');
    buf.writeln();
    buf.writeln('Guidelines:');
    buf.writeln('- Keep responses concise — the user is reading on an e-ink screen.');
    buf.writeln('- Use tools proactively when they would help answer the question.');
    buf.writeln('- Images will display in grayscale on the e-ink screen.');

    return Message(role: 'system', content: buf.toString());
  }

  Future<void> _validateApiKey() async {
    final warning = await OpenAIService.validateApiKey();
    if (warning != null) {
      _apiKeyWarning = warning;
      notifyListeners();
    }
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('sessions_index');
    if (json != null) {
      final list = jsonDecode(json) as List;
      _sessions = list
          .map((e) => Session.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'sessions_index',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> createNewSession() async {
    final session = Session();
    _sessions.insert(0, session);
    await _saveSessions();
    await loadSession(session.id);
  }

  Future<void> loadSession(String sessionId) async {
    _saveTimer?.cancel();
    if (_currentSessionId != null) {
      await _persistSession();
    }

    _currentSessionId = sessionId;
    _currentSession = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (_currentSession == null) return;
    _messages.clear();
    _error = null;

    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('session_$sessionId');
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final msgList = data['messages'] as List;
      _messages.addAll(
        msgList.map((m) => Message.fromJson(m as Map<String, dynamic>)),
      );
    }
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('session_$sessionId');
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final msgList = data['messages'] as List;
      for (final m in msgList) {
        final path = (m as Map<String, dynamic>)['imagePath'] as String?;
        if (path != null) await StorageService.deleteImage(path);
      }
      await prefs.remove('session_$sessionId');
    }

    _sessions.removeWhere((s) => s.id == sessionId);
    await _saveSessions();

    if (_currentSessionId == sessionId) {
      _currentSessionId = null;
      _currentSession = null;
      _messages.clear();
    }
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _persistSession);
  }

  Future<void> _persistSession() async {
    if (_currentSessionId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'messages': _messages.map((m) => m.toJson()).toList(),
    });
    await prefs.setString('session_$_currentSessionId', data);

    if (_currentSession != null) {
      _currentSession!.updatedAt = DateTime.now();
      if (_currentSession!.title == 'New Chat' && _messages.isNotEmpty) {
        final firstUserMsg =
            _messages.where((m) => m.role == 'user').firstOrNull;
        if (firstUserMsg != null) {
          final title = firstUserMsg.content;
          _currentSession!.title =
              title.length > 40 ? '${title.substring(0, 40)}...' : title;
        }
      }
      await _saveSessions();
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    if (_currentSessionId == null) {
      await createNewSession();
    }

    _messages.add(Message(role: 'user', content: trimmed));
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = [_buildSystemPrompt(), ..._messages];
      final response = await OpenAIService.sendWithTools(history);
      _messages.add(Message(
        role: 'assistant',
        content: response.content,
        imagePath: response.imagePath,
      ));
      _scheduleSave();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearConversation() {
    for (final msg in _messages) {
      if (msg.imagePath != null) {
        StorageService.deleteImage(msg.imagePath!);
      }
    }
    _messages.clear();
    _error = null;
    _scheduleSave();
    notifyListeners();
  }

  void dismissError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _persistSession();
    _connectivity.dispose();
    super.dispose();
  }
}
