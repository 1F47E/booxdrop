import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../services/eink_service.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  const ChatScreen({super.key, this.sessionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  ChatProvider? _chatProvider;

  @override
  void initState() {
    super.initState();
    EinkService.setRegalMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider = context.read<ChatProvider>();
      _chatProvider!.addListener(_onChatChanged);
      if (widget.sessionId != null) {
        _chatProvider!.loadSession(widget.sessionId!);
      }
    });
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_onChatChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChatChanged() {
    _scrollToBottom();
    EinkService.requestFullRefresh();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _confirmDeleteChat(BuildContext context, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This will permanently delete this conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteSession(provider.currentSessionId!);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _send(ChatProvider provider) {
    final text = _controller.text;
    if (text.trim().isEmpty || provider.isLoading) return;
    _controller.clear();
    provider.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              provider.currentSession?.title ?? 'Smarty Pants',
              style: const TextStyle(fontSize: 18, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  );
                },
                tooltip: 'Settings',
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: provider.currentSessionId == null
                    ? null
                    : () => _confirmDeleteChat(context, provider),
                tooltip: 'Delete chat',
              ),
            ],
          ),
          body: Column(
            children: [
              // Offline banner
              if (!provider.isOnline)
                _WarningBanner(
                  icon: Icons.wifi_off,
                  text: 'No internet connection',
                ),

              // API key warning banner
              if (provider.apiKeyWarning != null)
                _WarningBanner(
                  icon: Icons.warning_amber,
                  text: provider.apiKeyWarning!,
                ),

              // Message list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: provider.messages.length +
                      (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.messages.length) {
                      return _LoadingBubble();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child:
                          _MessageBubble(message: provider.messages[index]),
                    );
                  },
                ),
              ),

              // Error banner
              if (provider.error != null)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.black)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(
                              color: Colors.black, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: provider.dismissError,
                        child: const Text('Dismiss',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1, thickness: 1, color: Colors.black),

              // Input bar
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: 5,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: context.watch<SettingsProvider>().fontSize,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Message\u2026',
                          border: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: Colors.black),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                                color: Color(0xFF888888)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(provider),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Material(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _send(provider),
                          child: const Icon(Icons.send,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _WarningBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  static void _showFullScreenImage(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImage(path: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final settings = context.watch<SettingsProvider>();
    final fontSize = settings.fontSize;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: isUser
            ? BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(2),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              )
            : BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black,
                  fontSize: fontSize,
                ),
              ),
            if (message.imagePath != null) ...[
              if (message.content.isNotEmpty) const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showFullScreenImage(context, message.imagePath!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(message.imagePath!),
                    width: 256,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      '[Image not found]',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final toolStatus = context.watch<ChatProvider>().toolStatus;
    final fontSize = (context.watch<SettingsProvider>().fontSize - 5).clamp(10.0, double.infinity);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          toolStatus != null ? '\u23f3 $toolStatus' : '...',
          style: TextStyle(color: Colors.black54, fontSize: fontSize),
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String path;
  const _FullScreenImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('[Image not found]'),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Material(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
