import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../services/eink_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
    // Set REGAL refresh mode once at startup (best for text on e-ink)
    EinkService.setRegalMode();
    // Listen for chat changes to scroll + refresh e-ink after each update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatProvider = context.read<ChatProvider>();
      _chatProvider!.addListener(_onChatChanged);
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
        // jumpTo instead of animateTo — animations cause ghosting on e-ink
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
            title: const Text('BooxChat',
                style: TextStyle(fontSize: 18, color: Colors.white)),
            backgroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                onPressed: provider.clearConversation,
                tooltip: 'Clear conversation',
              ),
            ],
          ),
          body: Column(
            children: [
              // Message list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  itemCount: provider.messages.length +
                      (provider.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == provider.messages.length) {
                      return _LoadingBubble();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MessageBubble(
                          message: provider.messages[index]),
                    );
                  },
                ),
              ),

              // Error banner
              if (provider.error != null)
                Container(
                  color: const Color(0xFFFFEEEE),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(
                              color: Color(0xFF880000), fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: provider.dismissError,
                        child: const Text('Dismiss',
                            style:
                                TextStyle(color: Color(0xFF880000))),
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
                        decoration: InputDecoration(
                          hintText: 'Message…',
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

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: const Text(
          '...',
          style: TextStyle(color: Colors.black, fontSize: 20),
        ),
      ),
    );
  }
}
