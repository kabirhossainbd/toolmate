import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:path_provider/path_provider.dart';

/// Pending captures written by the BG isolate when the UI is gone.
/// Must NOT use Hive here — Hive cannot open the same box in two isolates,
/// which hangs cold start after swipe-from-recents.
const String kPendingNotificationsFile = 'pending_notifications.jsonl';

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
        // Don't auto-respawn after swipe-kill — that leaves a lone FlutterEngine
        // and blocks the next UI cold start (stuck splash).
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'Toolmate',
        initialNotificationContent: 'Listening for notifications',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Start only if UI asked us to and nothing is running.
    final running = await service.isRunning();
    if (!running) {
      await service.startService();
    }
  }

  /// Drain file-queue written by the background isolate into [onItem].
  static Future<int> drainPendingNotifications(
    FutureOr<void> Function(Map<String, dynamic> json) onItem,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$kPendingNotificationsFile');
      if (!await file.exists()) return 0;

      final raw = await file.readAsString();
      // Truncate immediately so we don't double-import on crash mid-drain.
      await file.writeAsString('', flush: true);
      if (raw.trim().isEmpty) return 0;

      var count = 0;
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final map = jsonDecode(trimmed) as Map<String, dynamic>;
          await onItem(map);
          count++;
        } catch (_) {
          // Skip corrupt lines.
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

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

    Future<void> appendPending(Map<String, dynamic> json) async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$kPendingNotificationsFile');
        await file.writeAsString(
          '${jsonEncode(json)}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (e) {
        // ignore: avoid_print
        print('Pending notification write failed: $e');
      }
    }

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

      final json = <String, dynamic>{
        'id': uniqueId,
        'packageName': packageName,
        'title': title,
        'text': content,
        'timestamp': now.toIso8601String(),
        'isRead': false,
        // Icons are large; UI/foreground path still gets them when alive.
        'senderIcon': null,
        'androidId': androidId,
      };

      // Always queue to disk so captures survive when UI isolate is dead.
      await appendPending(json);

      // Live UI isolate (if any) picks this up immediately.
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
