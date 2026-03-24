class Session {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;

  Session({
    String? id,
    this.title = 'New Chat',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? 'session_${DateTime.now().microsecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
