enum MessageStatus { sent, failed }

class Message {
  final String id;
  final String role; // 'system' | 'user' | 'assistant' | 'tool'
  final String content;
  final String? imagePath;
  final String? toolCallId; // for role='tool' responses
  final List<String>? quickReplies;
  final String? audioPath;
  final MessageStatus status;

  Message({
    String? id,
    required this.role,
    required this.content,
    this.imagePath,
    this.toolCallId,
    this.quickReplies,
    this.audioPath,
    this.status = MessageStatus.sent,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${role.hashCode}';

  Message copyWith({
    String? content,
    String? imagePath,
    String? audioPath,
    List<String>? quickReplies,
    MessageStatus? status,
  }) =>
      Message(
        id: id,
        role: role,
        content: content ?? this.content,
        imagePath: imagePath ?? this.imagePath,
        toolCallId: toolCallId,
        quickReplies: quickReplies ?? this.quickReplies,
        audioPath: audioPath ?? this.audioPath,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        if (imagePath != null) 'imagePath': imagePath,
        if (quickReplies != null) 'quickReplies': quickReplies,
        if (audioPath != null) 'audioPath': audioPath,
        if (status == MessageStatus.failed) 'status': 'failed',
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        role: json['role'] as String,
        content: (json['content'] as String?) ?? '',
        imagePath: json['imagePath'] as String?,
        quickReplies: (json['quickReplies'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        audioPath: json['audioPath'] as String?,
        status: json['status'] == 'failed'
            ? MessageStatus.failed
            : MessageStatus.sent,
      );
}
