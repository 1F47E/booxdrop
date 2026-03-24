class Message {
  final String id;
  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  Message({
    String? id,
    required this.role,
    required this.content,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${role.hashCode}';
}
