import 'dart:async';
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
      // Package name is essential to identify the source
      if (event.packageName == null) return;

      final incomingId = event.id?.toString() ?? '';
      final title = event.title ?? '';
      final content = event.content ?? '';
      final packageName = event.packageName!;

      // If both title and content are empty, it's likely a system noise or empty state
      if (title.isEmpty && content.isEmpty) return;

      final newNotif = NotificationModel(
        id: incomingId.isNotEmpty ? incomingId : DateTime.now().millisecondsSinceEpoch.toString(),
        packageName: packageName,
        title: title.isNotEmpty ? title : 'No title',
        text: content.isNotEmpty ? content : 'No content',
        timestamp: DateTime.now(),
        senderIcon: (event.largeIcon != null && event.largeIcon!.length > 500 * 1024) 
            ? null // Skip icon if it's too large (>500KB) to avoid TransactionTooLargeException
            : event.largeIcon,
      );

      // More robust deduplication:
      // We only skip if the title and content are IDENTICAL to the very last stored notification for THIS app.
      // This prevents progress bar spam (e.g., 50 notifications that all say "Downloading...")
      // but captures every meaningful change (e.g., "Downloading..." -> "Download successfully").
      
      bool shouldStore = true;
      final allNotifs = box.values.toList();
      
      if (allNotifs.isNotEmpty) {
        try {
          // Find the most recent notification from the same package
          final lastForApp = allNotifs.lastWhere((n) => n.packageName == packageName);
          if (lastForApp.title == newNotif.title && lastForApp.text == newNotif.text) {
            shouldStore = false; 
          }
        } catch (_) {
          // No previous notification for this app found, so we should store it
        }
      }

      if (shouldStore) {
        box.add(newNotif);
        
        // Notify foreground if it's active.
        // CRITICAL: We remove the senderIcon (Unit8List) from the Map before sending via invoke.
        // Inter-isolate communication (Binder on Android) has a 1MB limit.
        // Sending large icons causes TransactionTooLargeException.
        final json = newNotif.toJson();
        json['senderIcon'] = null; 
        service.invoke('onNotificationCaptured', json);
      }
    });
  }
}
