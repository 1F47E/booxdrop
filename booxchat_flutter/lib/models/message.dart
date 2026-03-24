class Message {
  final String id;
  final String role; // 'system' | 'user' | 'assistant' | 'tool'
  final String content;
  final String? imagePath;
  final String? toolCallId; // for role='tool' responses
  final List<String>? quickReplies;

  Message({
    String? id,
    required this.role,
    required this.content,
    this.imagePath,
    this.toolCallId,
    this.quickReplies,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${role.hashCode}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        if (imagePath != null) 'imagePath': imagePath,
        if (quickReplies != null) 'quickReplies': quickReplies,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        role: json['role'] as String,
        content: (json['content'] as String?) ?? '',
        imagePath: json['imagePath'] as String?,
        quickReplies: (json['quickReplies'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );
}
