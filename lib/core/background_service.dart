import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
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

    // O(1) dedupe cache — avoids box.values.toList() on every notification
    final lastByPackage = <String, List<String>>{};
    for (final n in box.values) {
      lastByPackage[n.packageName] = [n.title, n.text];
    }

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
    NotificationListenerService.notificationsStream.listen(
      (ServiceNotificationEvent event) {
      // Package name is essential to identify the source
      if (event.packageName == null) return;

      final incomingId = event.id?.toString() ?? '';
      final title = event.title ?? '';
      final content = event.content ?? '';
      final packageName = event.packageName!;

      // If both title and content are empty, it's likely a system noise or empty state
      if (title.isEmpty && content.isEmpty) return;

      // Cap icon size before Hive storage to avoid memory pressure from media apps (TikTok, etc.)
      Uint8List? senderIcon = event.largeIcon;
      if (senderIcon != null && senderIcon.length > 100 * 1024) {
        senderIcon = null;
      }

      final newNotif = NotificationModel(
        id: incomingId.isNotEmpty ? incomingId : DateTime.now().millisecondsSinceEpoch.toString(),
        packageName: packageName,
        title: title.isNotEmpty ? title : 'No title',
        text: content.isNotEmpty ? content : 'No content',
        timestamp: DateTime.now(),
        senderIcon: senderIcon,
      );

      // Skip identical spam for the same app (progress bars, etc.)
      final last = lastByPackage[packageName];
      if (last != null && last[0] == newNotif.title && last[1] == newNotif.text) {
        return;
      }
      lastByPackage[packageName] = [newNotif.title, newNotif.text];

      box.add(newNotif);

      // Notify foreground if it's active.
      // CRITICAL: strip senderIcon before Binder IPC (1MB limit).
      final json = newNotif.toJson();
      json['senderIcon'] = null;
      service.invoke('onNotificationCaptured', json);
    },
      onError: (Object error, StackTrace stack) {
        // Native plugin errors (e.g. oversized TikTok images) must not kill the isolate
        // ignore: avoid_print
        print('Notification stream error: $error');
      },
      cancelOnError: false,
    );
  }
}
