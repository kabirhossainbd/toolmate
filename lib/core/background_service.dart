import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import '../features/notification_history/notification_model.dart';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// OPTIONAL: Local Notifications to show background service status
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.low, // importance must be at least low to be visible
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'Toolmate Background Service',
        initialNotificationContent: 'Monitoring notifications',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Initialize Hive for background isolate
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(NotificationModelAdapter().typeId)) {
      Hive.registerAdapter(NotificationModelAdapter());
    }
    final box = await Hive.openBox<NotificationModel>('notifications');

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Start listening to notifications
    NotificationListenerService.notificationsStream.listen((ServiceNotificationEvent event) {
      if (event.packageName == null || event.title == null || event.content == null) return;

      final incomingId = event.id?.toString() ?? '';
      final title = event.title ?? 'No title';
      final content = event.content ?? 'No content';
      final packageName = event.packageName!;

      final newNotif = NotificationModel(
        id: incomingId.isNotEmpty ? incomingId : DateTime.now().millisecondsSinceEpoch.toString(),
        packageName: packageName,
        title: title,
        text: content,
        timestamp: DateTime.now(),
        senderIcon: event.largeIcon,
      );

      // Simple deduplication inside background isolate
      final existingNotifs = box.values.toList();
      final isDuplicate = existingNotifs.any((n) => 
        n.id == incomingId && n.title == title && n.text == content
      );

      if (!isDuplicate) {
        box.add(newNotif);
        // Notify foreground if it's active
        service.invoke('onNotificationCaptured', newNotif.toJson());
      }
    });
  }
}
