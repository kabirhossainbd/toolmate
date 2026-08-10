import 'dart:typed_data';

import 'notification_listener_service.dart';

class ServiceNotificationEvent {
  /// the notification id
  int? id;

  /// check if we can reply the Notification
  bool? canReply;

  /// if the notification has an extras image
  bool? haveExtraPicture;

  /// if the notification has been removed
  bool? hasRemoved;

  /// notification extras image
  Uint8List? extrasPicture;

  /// notification package name
  String? packageName;

  /// notification title (conversation / app title)
  String? title;

  /// MessagingStyle person name when available
  String? sender;

  /// Stable Android notification key (package|tag|id)
  String? key;

  /// Android notification tag
  String? tag;

  /// Notification channel id (O+)
  String? channelId;

  /// Android StatusBarNotification post time (ms since epoch)
  int? postTime;

  /// the notification app icon
  Uint8List? appIcon;

  /// the notification large icon (ex: album covers / avatar)
  Uint8List? largeIcon;

  /// the content of the notification
  String? content;

  /// if the notification is ongoing (cannot be dismissed and is in progress)
  bool? onGoing;

  ServiceNotificationEvent({
    this.id,
    this.canReply,
    this.haveExtraPicture,
    this.hasRemoved,
    this.extrasPicture,
    this.packageName,
    this.title,
    this.sender,
    this.key,
    this.tag,
    this.channelId,
    this.postTime,
    this.appIcon,
    this.largeIcon,
    this.content,
    this.onGoing,
  });

  ServiceNotificationEvent.fromMap(Map<dynamic, dynamic> map) {
    id = map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}');
    canReply = map['canReply'] == true;
    haveExtraPicture = map['haveExtraPicture'] == true;
    hasRemoved = map['hasRemoved'] == true;
    extrasPicture = map['notificationExtrasPicture'] is Uint8List
        ? map['notificationExtrasPicture'] as Uint8List
        : null;
    packageName = map['packageName']?.toString();
    title = map['title']?.toString();
    sender = map['sender']?.toString();
    key = map['key']?.toString();
    tag = map['tag']?.toString();
    channelId = map['channelId']?.toString();
    final rawPost = map['postTime'];
    if (rawPost is int) {
      postTime = rawPost;
    } else if (rawPost != null) {
      postTime = int.tryParse(rawPost.toString());
    }
    appIcon = map['appIcon'] is Uint8List ? map['appIcon'] as Uint8List : null;
    largeIcon =
        map['largeIcon'] is Uint8List ? map['largeIcon'] as Uint8List : null;
    content = map['content']?.toString();
    onGoing = map['onGoing'] == true;
  }

  /// Best display title: person/sender first, then notification title.
  String get displayTitle {
    final s = sender?.trim();
    if (s != null && s.isNotEmpty) return s;
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    return 'No title';
  }

  /// send a direct message reply to the incoming notification
  Future<bool> sendReply(String message) async {
    if (canReply != true) throw Exception("The notification is not replyable");
    try {
      return await methodeChannel.invokeMethod<bool>("sendReply", {
            'message': message,
            'notificationId': id,
          }) ??
          false;
    } catch (e) {
      rethrow;
    }
  }

  @override
  String toString() {
    return '''ServiceNotificationEvent(
      id: $id
      key: $key
      can reply: $canReply
      packageName: $packageName
      title: $title
      sender: $sender
      content: $content
      hasRemoved: $hasRemoved
      haveExtraPicture: $haveExtraPicture
      onGoing: $onGoing
      ''';
  }
}
