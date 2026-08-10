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

/// Collapse whitespace / casing for stable grouping.
String normalizeNotifText(String input) {
  return sanitizeUtf16(input)
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

/// Strip trailing “(2)” / “· 3 new” noise so stacked shade updates merge.
String stripCountSuffix(String input) {
  return input
      .replaceAll(RegExp(r'\s*[\(（]\d+[\)）]\s*$'), '')
      .replaceAll(RegExp(r'\s*[·•]\s*\d+\s*new\b.*$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+\d+\s+new messages?$', caseSensitive: false), '')
      .trim();
}

/// Content fingerprint used to merge identical notifications.
String notificationContentKey({
  required String packageName,
  required String title,
  required String text,
}) {
  final t = stripCountSuffix(normalizeNotifText(title));
  final x = stripCountSuffix(normalizeNotifText(text));
  return '$packageName|$t|$x';
}

@HiveType(typeId: 4)
class NotificationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String packageName;

  @HiveField(2)
  String title;

  @HiveField(3)
  String text;

  @HiveField(4)
  DateTime timestamp;

  /// Sender's profile photo (largeIcon from WhatsApp/Messenger notifications)
  @HiveField(5)
  Uint8List? senderIcon;

  @HiveField(6, defaultValue: false)
  bool isRead;

  /// How many identical notifications were merged into this row.
  @HiveField(7, defaultValue: 1)
  int count;

  /// Android StatusBarNotification key when known (package|tag|id).
  @HiveField(8, defaultValue: '')
  String androidKey;

  NotificationModel({
    required this.id,
    required this.packageName,
    required String title,
    required String text,
    required this.timestamp,
    this.senderIcon,
    this.isRead = false,
    this.count = 1,
    this.androidKey = '',
  })  : title = sanitizeUtf16(title),
        text = sanitizeUtf16(text);

  String get senderName {
    final t = title.trim();
    return t.isNotEmpty ? t : 'Unknown';
  }

  String get contentKey => notificationContentKey(
        packageName: packageName,
        title: title,
        text: text,
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageName': packageName,
      'title': title,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'senderIcon': senderIcon,
      'isRead': isRead,
      'count': count,
      'androidKey': androidKey,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    Uint8List? icon;
    final rawIcon = json['senderIcon'];
    if (rawIcon is Uint8List) {
      icon = rawIcon;
    } else if (rawIcon is List) {
      icon = Uint8List.fromList(List<int>.from(rawIcon));
    }

    final rawCount = json['count'];
    final count = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? 1;

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      packageName: json['packageName']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp'].toString()),
      senderIcon: icon,
      isRead: json['isRead'] == true,
      count: count < 1 ? 1 : count,
      androidKey: json['androidKey']?.toString() ??
          json['key']?.toString() ??
          '',
    );
  }
}
