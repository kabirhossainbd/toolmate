class NotesModel {
  final String id;
  String title;
  String content;
  DateTime updatedAt;
  bool isPinned;

  NotesModel({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned,
      };

  factory NotesModel.fromMap(Map<dynamic, dynamic> map) => NotesModel(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
        isPinned: map['isPinned'] == true,
      );

  NotesModel copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? isPinned,
  }) =>
      NotesModel(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        updatedAt: updatedAt ?? this.updatedAt,
        isPinned: isPinned ?? this.isPinned,
      );
}
