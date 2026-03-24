class Message {
  final String id;
  final String role; // 'system' | 'user' | 'assistant' | 'tool'
  final String content;
  final String? imagePath;
  final String? toolCallId; // for role='tool' responses

  Message({
    String? id,
    required this.role,
    required this.content,
    this.imagePath,
    this.toolCallId,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${role.hashCode}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        if (imagePath != null) 'imagePath': imagePath,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        role: json['role'] as String,
        content: (json['content'] as String?) ?? '',
        imagePath: json['imagePath'] as String?,
      );
}
