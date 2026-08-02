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

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'Toolmate Listener',
      description: 'Keeps notification capture running in the background.',
      importance: Importance.low,
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
        initialNotificationTitle: 'Toolmate',
        initialNotificationContent: 'Listening for notifications',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Ensure service is up after configure.
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(NotificationModelAdapter().typeId)) {
      Hive.registerAdapter(NotificationModelAdapter());
    }
    final box = await Hive.openBox<NotificationModel>('notifications');

    // Short-window dedupe: package + title + text (allows real updates later).
    final recentKeys = <String, int>{};
    const dedupeMs = 2500;

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

    bool shouldSkip(ServiceNotificationEvent event) {
      if (event.hasRemoved == true) return true;
      if (event.packageName == null || event.packageName!.isEmpty) return true;

      final title = (event.title ?? '').trim();
      final content = (event.content ?? '').trim();
      if (title.isEmpty && content.isEmpty) return true;

      // Skip noisy ongoing progress (downloads/music) when content barely changes.
      if (event.onGoing == true) {
        final lower = '$title $content'.toLowerCase();
        if (lower.contains('%') ||
            lower.contains('downloading') ||
            lower.contains('upload') ||
            lower.contains('playing')) {
          return true;
        }
      }
      return false;
    }

    String fingerprint(String packageName, String title, String text) =>
        '$packageName|$title|$text';

    Future<void> persist(ServiceNotificationEvent event) async {
      if (shouldSkip(event)) return;

      final packageName = event.packageName!;
      final title =
          (event.title ?? '').trim().isNotEmpty ? event.title!.trim() : 'No title';
      final content = (event.content ?? '').trim().isNotEmpty
          ? event.content!.trim()
          : 'No content';

      final now = DateTime.now();
      final fp = fingerprint(packageName, title, content);
      final lastAt = recentKeys[fp];
      if (lastAt != null && now.millisecondsSinceEpoch - lastAt < dedupeMs) {
        return;
      }
      recentKeys[fp] = now.millisecondsSinceEpoch;

      // Bound memory of dedupe map.
      if (recentKeys.length > 400) {
        final cutoff = now.millisecondsSinceEpoch - 60 * 1000;
        recentKeys.removeWhere((_, ts) => ts < cutoff);
      }

      Uint8List? senderIcon = event.largeIcon;
      if (senderIcon != null && senderIcon.length > 100 * 1024) {
        senderIcon = null;
      }

      // Stable id from content — Android notif ids are reused; dual-listen won't double-save.
      final androidId = event.id?.toString() ?? '0';
      final uniqueId =
          '${packageName}_${androidId}_${Object.hash(title, content)}';

      // Already stored (e.g. UI isolate also captured this).
      final already = box.values.any((n) => n.id == uniqueId);
      if (already) return;

      final newNotif = NotificationModel(
        id: uniqueId,
        packageName: packageName,
        title: title,
        text: content,
        timestamp: now,
        senderIcon: senderIcon,
      );

      await box.add(newNotif);

      final json = newNotif.toJson();
      json['senderIcon'] = null;
      json['androidId'] = androidId;
      service.invoke('onNotificationCaptured', json);
    }

    NotificationListenerService.notificationsStream.listen(
      (event) {
        // Fire-and-forget; errors must not cancel the stream.
        unawaited(persist(event));
      },
      onError: (Object error, StackTrace stack) {
        // ignore: avoid_print
        print('Notification stream error: $error');
      },
      cancelOnError: false,
    );

    // Backfill anything already visible in the shade when service starts.
    try {
      final active = await NotificationListenerService.getActiveNotifications();
      for (final event in active) {
        await persist(event);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Active notification backfill failed: $e');
    }
  }
}
