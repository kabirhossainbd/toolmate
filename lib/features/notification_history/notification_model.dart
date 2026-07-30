import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'notification_model.g.dart';

/// Strips unpaired UTF-16 surrogates that crash Flutter Text/TextSpan.
String sanitizeUtf16(String? input) {
  if (input == null || input.isEmpty) return '';
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final unit = input.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 < input.length) {
        final next = input.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          buffer.writeCharCode(unit);
          buffer.writeCharCode(next);
          i++;
          continue;
        }
      }
      buffer.write('\uFFFD');
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      buffer.write('\uFFFD');
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Safe single-grapheme initial for avatars (avoids unpaired surrogate Text crashes).
String safeInitial(String input, [String fallback = '?']) {
  final cleaned = sanitizeUtf16(input).trim();
  if (cleaned.isEmpty) return fallback;
  return String.fromCharCodes(cleaned.runes.take(1)).toUpperCase();
}

@HiveType(typeId: 4)
class NotificationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String packageName;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String text;

  @HiveField(4)
  final DateTime timestamp;

  /// Sender's profile photo (largeIcon from WhatsApp/Messenger notifications)
  @HiveField(5)
  final Uint8List? senderIcon;

  NotificationModel({
    required this.id,
    required this.packageName,
    required String title,
    required String text,
    required this.timestamp,
    this.senderIcon,
  })  : title = sanitizeUtf16(title),
        text = sanitizeUtf16(text);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageName': packageName,
      'title': title,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'senderIcon': senderIcon,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      packageName: json['packageName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      senderIcon: json['senderIcon'] != null ? Uint8List.fromList(List<int>.from(json['senderIcon'])) : null,
    );
  }
}
