import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'notification_model.g.dart';

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
    required this.title,
    required this.text,
    required this.timestamp,
    this.senderIcon,
  });

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
      id: json['id'],
      packageName: json['packageName'],
      title: json['title'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      senderIcon: json['senderIcon'] != null ? Uint8List.fromList(List<int>.from(json['senderIcon'])) : null,
    );
  }
}

