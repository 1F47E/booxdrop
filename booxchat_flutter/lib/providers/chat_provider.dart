import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/session.dart';
import '../services/openai_service.dart';
import '../services/storage_service.dart';
import '../services/connectivity_service.dart';
import '../services/log_service.dart';
import 'settings_provider.dart';

final _log = LogService.instance;

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
  String? _toolStatus;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentSessionId => _currentSessionId;
  Session? get currentSession => _currentSession;
  List<Session> get sessions => List.unmodifiable(_sessions);
  bool get isOnline => _isOnline;
  String? get apiKeyWarning => _apiKeyWarning;
  String? get toolStatus => _toolStatus;

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
    buf.writeln('- generate_image: Generate a new image from a text description.');
    buf.writeln('- edit_image: Edit or modify a previously generated image.');
    if (_settings.availableTtsProviders.isNotEmpty) {
      buf.writeln('- text_to_speech: Convert text to speech audio. Use when the user '
          'asks to hear something aloud, narrate, or wants voice output. '
          'Keep text under 500 characters (~1 minute). For longer content, summarize or ask to continue.');
    }
    buf.writeln();
    buf.writeln('Guidelines:');
    buf.writeln('- Keep responses concise — the user is reading on an e-ink screen.');
    buf.writeln('- Use tools proactively when they would help answer the question.');
    buf.writeln('- Images will display in grayscale on the e-ink screen.');
    buf.writeln('- You have two image tools: generate_image (create new) and edit_image (modify existing).');
    buf.writeln('- Use edit_image when the user wants to change, adjust, or modify a previously generated image.');
    buf.writeln('- Use generate_image only for brand new images with no prior image to edit.');
    buf.writeln('- When generating or editing images, do NOT add any text commentary — '
        'the image is shown directly to the user.');
    if (_settings.availableTtsProviders.isNotEmpty) {
      buf.writeln('- When using text_to_speech, write natural spoken prose — no bullet points or markdown.');
      buf.writeln('- After text_to_speech, do NOT repeat the spoken text. Just acknowledge briefly.');
    }
    buf.writeln();
    buf.writeln('QUICK REPLIES: At the end of your response, optionally suggest up to 4 '
        'short follow-up replies the user might want to send next. Format them as a JSON '
        'array inside an HTML comment at the very end of your message, like this: '
        '<!--quick_replies:["Reply 1","Reply 2","Reply 3"]-->. '
        'Keep each reply under 30 characters. Only include when natural follow-ups exist. '
        'Do NOT include the quick replies tag when generating images.');

    return Message(role: 'system', content: buf.toString());
  }

  static ({String content, List<String>? quickReplies}) _parseQuickReplies(
      String content) {
    final regex = RegExp(r'<!--quick_replies:(\[.*?\])-->', dotAll: true);
    final match = regex.firstMatch(content);
    if (match == null) return (content: content, quickReplies: null);

    final clean = content.replaceAll(regex, '').trimRight();
    try {
      final list = (jsonDecode(match.group(1)!) as List)
          .map((e) => e.toString())
          .toList();
      return (content: clean, quickReplies: list.isEmpty ? null : list);
    } catch (_) {
      return (content: clean, quickReplies: null);
    }
  }

  Future<void> _validateApiKey() async {
    final warning = await OpenAIService.validateApiKey();
    if (warning != null) {
      _apiKeyWarning = warning;
      notifyListeners();
    }
  }

  Future<void> _loadSessions() async {
    // Try file-based storage first
    var json = await StorageService.loadSessionIndex();

    // Migrate from SharedPreferences if file storage is empty
    if (json == null) {
      final prefs = await SharedPreferences.getInstance();
      json = prefs.getString('sessions_index');
      if (json != null) {
        // Migrate index to file
        await StorageService.saveSessionIndex(json);
        // Migrate each session's messages
        final list = jsonDecode(json) as List;
        for (final e in list) {
          final id = (e as Map<String, dynamic>)['id'] as String;
          final msgJson = prefs.getString('session_$id');
          if (msgJson != null) {
            await StorageService.saveSessionMessages(id, msgJson);
            await prefs.remove('session_$id');
          }
        }
        await prefs.remove('sessions_index');
      }
    }

    if (json != null) {
      final list = jsonDecode(json) as List;
      _sessions = list
          .map((e) => Session.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _saveSessions() async {
    await StorageService.saveSessionIndex(
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> createNewSession() async {
    final session = Session();
    _sessions.insert(0, session);
    await _saveSessions();
    await loadSession(session.id);
  }

  /// Creates a new session pre-seeded with an existing image so the user
  /// can chat about it (e.g. "make it bigger", "add a rainbow").
  Future<void> createSessionWithImage(String imagePath) async {
    _saveTimer?.cancel();
    if (_currentSessionId != null) await _persistSession();

    final session = Session();
    _sessions.insert(0, session);
    await _saveSessions();

    _currentSessionId = session.id;
    _currentSession = session;
    _messages.clear();
    _error = null;
    _messages.add(Message(role: 'assistant', content: '', imagePath: imagePath));
    await _persistSession();
    notifyListeners();
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

    final json = await StorageService.loadSessionMessages(sessionId);
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
    // Flush pending save so disk state matches in-memory state
    _saveTimer?.cancel();
    if (_currentSessionId == sessionId) {
      await _persistSession();
    }

    // Delete images and audio from this session
    final json = await StorageService.loadSessionMessages(sessionId);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final msgList = data['messages'] as List;
      for (final m in msgList) {
        final map = m as Map<String, dynamic>;
        final imgPath = map['imagePath'] as String?;
        if (imgPath != null) await StorageService.deleteImage(imgPath);
        final audPath = map['audioPath'] as String?;
        if (audPath != null) await StorageService.deleteAudio(audPath);
      }
    }
    await StorageService.deleteSessionData(sessionId);

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
    final data = jsonEncode({
      'messages': _messages.map((m) => m.toJson()).toList(),
    });
    await StorageService.saveSessionMessages(_currentSessionId!, data);

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

    _log.info('chat', 'User: ${trimmed.length > 50 ? '${trimmed.substring(0, 50)}...' : trimmed}');
    _messages.add(Message(role: 'user', content: trimmed));
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = [_buildSystemPrompt(), ..._messages];
      final response = await OpenAIService.sendWithTools(
        history,
        settings: _settings,
        kidsMode: _settings.kidsMode,
        onToolCall: (status) {
          _toolStatus = status;
          notifyListeners();
        },
      );
      final parsed = _parseQuickReplies(response.content);
      _messages.add(Message(
        role: 'assistant',
        content: parsed.content,
        imagePath: response.imagePath,
        audioPath: response.audioPath,
        quickReplies: parsed.quickReplies,
      ));
      _scheduleSave();
    } catch (e) {
      _log.error('chat', 'Error: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      _toolStatus = null;
      notifyListeners();
    }
  }

  void clearConversation() {
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
