import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/openai_service.dart';

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  static final _systemPrompt =
      Message(role: 'system', content: 'You are a helpful assistant.');

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _messages.add(Message(role: 'user', content: trimmed));
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final history = [_systemPrompt, ..._messages];
      final reply = await OpenAIService.sendMessages(history);
      _messages.add(Message(role: 'assistant', content: reply));
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearConversation() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  void dismissError() {
    _error = null;
    notifyListeners();
  }
}
