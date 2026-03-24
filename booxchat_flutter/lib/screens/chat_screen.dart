import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'full_screen_image.dart';
import '../data/prompt_suggestions.dart';
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
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Chats',
              ),
            ),
            title: Text(
              provider.currentSession?.title ?? 'Smarty Pants',
              style: const TextStyle(fontSize: 18, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: provider.currentSessionId == null
                    ? null
                    : () => _confirmDeleteChat(context, provider),
                tooltip: 'Delete chat',
              ),
            ],
          ),
          drawer: _HistoryDrawer(provider: provider),
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

              // Message list or conversation starters
              Expanded(
                child: provider.messages.isEmpty && !provider.isLoading
                    ? _ConversationStarters(
                        onTap: (text) => provider.sendMessage(text),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        itemCount: provider.messages.length +
                            (provider.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == provider.messages.length) {
                            return _LoadingBubble();
                          }
                          final message = provider.messages[index];
                          final isLastAssistant =
                              index == provider.messages.length - 1 &&
                                  message.role == 'assistant' &&
                                  !provider.isLoading &&
                                  message.quickReplies != null &&
                                  message.quickReplies!.isNotEmpty;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MessageBubble(key: ValueKey(message.id), message: message),
                                if (isLastAssistant)
                                  _QuickReplies(
                                    replies: message.quickReplies!,
                                    onTap: (text) =>
                                        provider.sendMessage(text),
                                  ),
                              ],
                            ),
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

class _MessageBubble extends StatefulWidget {
  final Message message;
  const _MessageBubble({super.key, required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _toggling = false;
  StreamSubscription? _playerSub;

  static void _showFullScreenImage(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(path: path),
      ),
    );
  }

  void _toggleAudio() async {
    if (_toggling) return;
    _toggling = true;
    try {
      if (_player == null) {
        _player = AudioPlayer();
        _playerSub = _player!.playerStateStream.listen((state) {
          final playing = state.playing &&
              state.processingState != ProcessingState.completed;
          if (mounted && _isPlaying != playing) {
            setState(() => _isPlaying = playing);
          }
          if (state.processingState == ProcessingState.completed) {
            _player?.stop();
            _player?.seek(Duration.zero);
          }
        });
      }

      if (_isPlaying) {
        await _player!.stop();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _player!.setFilePath(widget.message.audioPath!);
        await _player!.play();
      }
    } finally {
      _toggling = false;
    }
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
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
        child: Builder(builder: (context) {
          // Strip markdown image syntax (![alt](url)) the AI may include in text
          final displayText = message.content
              .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
              .trim();
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (displayText.isNotEmpty)
              Text(
                displayText,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black,
                  fontSize: fontSize,
                ),
              ),
            if (message.audioPath != null && !isUser) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: _toggleAudio,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPlaying ? Icons.stop : Icons.play_arrow,
                      color: Colors.black,
                      size: 28,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isPlaying ? 'Stop' : 'Play',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            if (message.imagePath != null) ...[
              if (displayText.isNotEmpty) const SizedBox(height: 8),
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
        );
        }),
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

class _ConversationStarters extends StatelessWidget {
  final void Function(String text) onTap;
  const _ConversationStarters({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final suggestions = getRandomSuggestions(
      count: 6,
      kidsMode: settings.kidsMode,
      kidsAge: settings.kidsAge,
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              settings.kidsMode ? 'What do you want to do?' : 'Start a conversation',
              style: TextStyle(
                fontSize: settings.kidsMode ? 22.0 : 16.0,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: suggestions.map((text) => OutlinedButton(
                onPressed: () => onTap(text),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: settings.kidsMode ? 18.0 : 14.0,
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickReplies extends StatelessWidget {
  final List<String> replies;
  final void Function(String text) onTap;
  const _QuickReplies({required this.replies, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: replies.map((text) => OutlinedButton(
          onPressed: () => onTap(text),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.black54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: settings.kidsMode ? 16.0 : 13.0),
          ),
        )).toList(),
      ),
    );
  }
}

class _HistoryDrawer extends StatefulWidget {
  final ChatProvider provider;
  const _HistoryDrawer({required this.provider});

  @override
  State<_HistoryDrawer> createState() => _HistoryDrawerState();
}

class _HistoryDrawerState extends State<_HistoryDrawer> {
  int _visibleCount = 20;

  @override
  Widget build(BuildContext context) {
    final sessions = widget.provider.sessions;
    final currentId = widget.provider.currentSessionId;
    final visible = sessions.take(_visibleCount).toList();
    final hasMore = sessions.length > _visibleCount;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: () {
                      widget.provider.createNewSession();
                      Navigator.pop(context);
                    },
                    tooltip: 'New chat',
                  ),
                ],
              ),
            ),

            // Session list
            Expanded(
              child: sessions.isEmpty
                  ? const Center(
                      child: Text(
                        'No chats yet',
                        style: TextStyle(color: Colors.black38, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visible.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() => _visibleCount += 20);
                                },
                                child: const Text(
                                  'Load more',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          );
                        }
                        final session = visible[index];
                        final isCurrent = session.id == currentId;
                        return Dismissible(
                          key: ValueKey(session.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.black12,
                            child: const Icon(Icons.delete,
                                color: Colors.black54),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete chat?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancel',
                                        style: TextStyle(
                                            color: Colors.black)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Delete',
                                        style: TextStyle(
                                            color: Colors.black)),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) {
                            widget.provider.deleteSession(session.id);
                          },
                          child: ListTile(
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.black,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              _formatDate(session.updatedAt),
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12),
                            ),
                            selected: isCurrent,
                            selectedTileColor: Colors.black.withValues(alpha: 0.05),
                            onTap: () {
                              widget.provider.loadSession(session.id);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Settings at bottom
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black)),
              ),
              child: ListTile(
                leading: const Icon(Icons.settings, color: Colors.black),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.black),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

