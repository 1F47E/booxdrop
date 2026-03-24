import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/session.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _currentSessionId;
  Session? _currentSession;
  List<Session> _sessions = [];
  Timer? _saveTimer;
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isOnline = true;

  static final _systemPrompt = Message(
    role: 'system',
    content: 'You are a helpful assistant on a Boox e-ink tablet device.\n\n'
        'You have access to the following tools:\n'
        '- web_search: Search the web for current information. Use when asked about recent events, facts you\'re unsure about, or when the user explicitly asks to search.\n'
        '- fetch_page: Fetch and read the content of a specific URL. Use when the user provides a URL or when you need detailed information from a search result.\n'
        '- generate_image: Generate an image from a text description using AI. Use when the user asks you to create, draw, generate, or make any kind of image, picture, or illustration.\n\n'
        'Guidelines:\n'
        '- Keep responses concise — the user is reading on an e-ink screen with limited refresh rate.\n'
        '- Use tools proactively when they would help answer the user\'s question.\n'
        '- When generating images, note they will display in grayscale on the e-ink screen.\n'
        '- When you cannot answer from memory, search the web rather than guessing.',
  );

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentSessionId => _currentSessionId;
  Session? get currentSession => _currentSession;
  List<Session> get sessions => List.unmodifiable(_sessions);
  bool get isOnline => _isOnline;

  ChatProvider() {
    _connectivity.startListening((online) {
      _isOnline = online;
      notifyListeners();
    });
    _loadSessions();
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
    // Save current session before switching
    _saveTimer?.cancel();
    if (_currentSessionId != null) {
      await _persistSession();
    }

    _currentSessionId = sessionId;
    _currentSession = _sessions.firstWhere((s) => s.id == sessionId);
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
    // Delete image files for this session
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

    // Update session metadata
    if (_currentSession != null) {
      _currentSession!.updatedAt = DateTime.now();
      // Auto-title from first user message
      if (_currentSession!.title == 'New Chat' && _messages.isNotEmpty) {
        final firstUserMsg = _messages.where((m) => m.role == 'user').firstOrNull;
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

    // Auto-create session if none active
    if (_currentSessionId == null) {
      await createNewSession();
    }

    _messages.add(Message(role: 'user', content: trimmed));
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = [_systemPrompt, ..._messages];
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
    // Delete image files
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
