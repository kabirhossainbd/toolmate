import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_event.dart';

const MethodChannel methodeChannel =
    MethodChannel('x-slayer/notifications_channel');
const EventChannel _eventChannel = EventChannel('x-slayer/notifications_event');
Stream<ServiceNotificationEvent>? _stream;

class NotificationListenerService {
  NotificationListenerService._();

  /// stream the incoming notifications events
  static Stream<ServiceNotificationEvent> get notificationsStream {
    if (Platform.isAndroid) {
      _stream ??=
          _eventChannel.receiveBroadcastStream().map<ServiceNotificationEvent>(
                (event) => ServiceNotificationEvent.fromMap(event),
              );
      return _stream!;
    }
    throw Exception("Notifications API exclusively available on Android!");
  }

  /// request notification permission
  /// it will open the notification settings page and return `true` once the permission granted.
  static Future<bool> requestPermission() async {
    try {
      final result = await methodeChannel.invokeMethod('requestPermission');
      return result == true;
    } on PlatformException catch (error) {
      log("$error");
      return false;
    }
  }

  /// check if notification permission is enebaled
  static Future<bool> isPermissionGranted() async {
    try {
      return await methodeChannel.invokeMethod('isPermissionGranted');
    } on PlatformException catch (error) {
      log("$error");
      return false;
    }
  }

  /// Ask the system to bind the listener again (needed after process changes).
  static Future<void> requestRebind() async {
    if (!Platform.isAndroid) return;
    try {
      await methodeChannel.invokeMethod('requestRebind');
    } on PlatformException catch (error) {
      log("$error");
    }
  }

  /// Pull notifications the Android listener persisted to disk.
  static Future<List<Map<String, dynamic>>> drainPendingQueue() async {
    if (!Platform.isAndroid) return const [];
    try {
      final result = await methodeChannel.invokeMethod('drainPendingQueue');
      if (result is! List) return const [];
      return result
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on PlatformException catch (error) {
      log("drainPendingQueue error: $error");
      return const [];
    }
  }

  /// get currently active notifications
  static Future<List<ServiceNotificationEvent>> getActiveNotifications() async {
    try {
      final List<dynamic> result =
      await methodeChannel.invokeMethod('getActiveNotifications');
      return result
          .map((item) => ServiceNotificationEvent.fromMap(item))
          .toList();
    } on PlatformException catch (error) {
      log("getActiveNotifications error: $error");
      return [];
    }
  }
}
