class ClipboardItem {
  final String id;
  final String text;
  final DateTime createdAt;

  const ClipboardItem({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ClipboardItem.fromMap(Map<dynamic, dynamic> map) => ClipboardItem(
        id: map['id']?.toString() ?? '',
        text: map['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}
