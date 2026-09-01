import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'constants/app_constants.dart';
import '../features/notification_history/notification_model.dart';
import '../features/user_profile/user_profile_model.dart';
import '../features/video_downloader/video_model.dart';

/// Opens Hive without blocking the first Flutter frame.
///
/// After swipe-from-recents the process often stays alive (NotificationListener).
/// The previous isolate is gone but `.lock` files remain, so [Hive.openBox]
/// can hang forever. That must never run before the first frame, or Android
/// stays on the native splash (`onPreDraw return false`).
class HiveBootstrap {
  HiveBootstrap._();

  static const _openTimeout = Duration(seconds: 2);
  static const _initTimeout = Duration(seconds: 3);

  static bool ready = false;
  static Future<void>? _inFlight;

  static Future<void> init() async {
    if (ready) return;
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final work = _doInit();
    _inFlight = work;
    try {
      await work;
    } finally {
      _inFlight = null;
    }
  }

  static Future<void> _doInit() async {
    if (ready) return;
    try {
      final dir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 2));
      await _deleteLockFilesIn(dir);

      // Avoid Hive.initFlutter() — it re-enters the binding and can stall
      // when a leftover FlutterEngine is still in the process.
      Hive.init(dir.path);
      _registerAdapters();

      await _openAll();
      ready = true;
    } on TimeoutException {
      debugPrint('HiveBootstrap timed out — recovering locks');
      try {
        await _recoverAndReopen();
        ready = true;
      } catch (e) {
        debugPrint('HiveBootstrap recover failed: $e');
      }
    } catch (e) {
      debugPrint('HiveBootstrap failed: $e');
    }
  }

  static Future<void> _openAll() async {
    // Small boxes first so settings/theme work even if notifications is huge.
    await _open(AppConstants.boxAppSettings);
    await _openTyped<UserProfileModel>(AppConstants.boxUserProfile);
    await _open(AppConstants.boxNotes);
    await _open(AppConstants.boxClipboard);
    await _openTyped<VideoModel>(AppConstants.boxVideoHistory);
    try {
      await _openTyped<NotificationModel>(AppConstants.boxNotifications);
    } catch (e) {
      debugPrint('notifications box skipped: $e');
    }
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(VideoModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(UserProfileModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(NotificationModelAdapter());
    }
  }

  static Future<void> _open(String name) async {
    if (Hive.isBoxOpen(name)) return;
    try {
      await Hive.openBox(name).timeout(_openTimeout);
    } catch (e) {
      debugPrint('Hive.openBox($name) failed: $e');
    }
  }

  static Future<void> _openTyped<T>(String name) async {
    if (Hive.isBoxOpen(name)) return;
    try {
      await Hive.openBox<T>(name).timeout(_openTimeout);
    } catch (e) {
      debugPrint('Hive.openBox<$T>($name) failed: $e');
    }
  }

  static Future<void> _recoverAndReopen() async {
    try {
      await Hive.close().timeout(const Duration(milliseconds: 400));
    } catch (_) {}
    try {
      final dir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(seconds: 2));
      await _deleteLockFilesIn(dir);
      Hive.init(dir.path);
    } catch (_) {}
    _registerAdapters();
    await _openAll().timeout(_initTimeout);
  }

  static Future<void> _deleteLockFilesIn(Directory dir) async {
    try {
      if (!dir.existsSync()) return;
      await for (final entity
          in dir.list(recursive: false, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.lock')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
