import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/clipboard_manager/clipboard_controller.dart';
import '../features/clipboard_manager/clipboard_screen.dart';
import '../features/home/home_controller.dart';
import '../features/home/home_screen.dart';
import '../features/notes/notes_controller.dart';
import '../features/notes/notes_screen.dart';
import '../features/notification_history/notification_history_controller.dart';
import '../features/notification_history/notification_history_screen.dart';
import '../features/notification_history/notification_settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/storage_analyzer/duplicate_files_screen.dart';
import '../features/storage_analyzer/duplicate_images_screen.dart';
import '../features/storage_analyzer/large_files_screen.dart';
import '../features/storage_analyzer/storage_analyzer_controller.dart';
import '../features/storage_analyzer/storage_analyzer_screen.dart';
import '../features/storage_analyzer/storage_explorer_screen.dart';
import '../features/unit_converter/unit_converter_controller.dart';
import '../features/unit_converter/unit_converter_screen.dart';
import '../features/user_profile/user_profile_controller.dart';
import '../features/user_profile/user_profile_screen.dart';
import '../features/video_downloader/video_downloader_controller.dart';
import '../features/video_downloader/video_downloader_screen.dart';
import 'app_routes.dart';

/// Only routes for shipped, fully working features.
class AppPages {
  AppPages._();

  static const initial = Routes.home;
  /// Matches Flutter CupertinoPageRoute (~400ms) for native push/pop feel.
  static const _transition = Transition.native;
  static const _duration = Duration(milliseconds: 400);

  static void _ensureNotificationController() {
    if (!Get.isRegistered<NotificationHistoryController>()) {
      Get.put(NotificationHistoryController(), permanent: true);
    }
  }

  static void _ensureStorageController() {
    if (!Get.isRegistered<StorageAnalyzerController>()) {
      Get.put(StorageAnalyzerController(), permanent: true);
    }
  }

  static void _ensureHomeController() {
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController(), permanent: true);
    }
  }

  static GetPage<T> _page<T>({
    required String name,
    required GetPageBuilder page,
    void Function()? bind,
    Transition? transition,
    Duration? transitionDuration,
  }) {
    return GetPage<T>(
      name: name,
      page: page,
      binding: bind == null ? null : BindingsBuilder(bind),
      transition: transition ?? _transition,
      transitionDuration: transitionDuration ?? _duration,
      // Keep every feature on the root navigator. Slash-prefixed names
      // otherwise spawn a nested navigator that eats later Get.toNamed calls.
      participatesInRootNavigator: true,
      // iOS-style interactive edge swipe; Android still uses system back.
      popGesture: true,
      gestureWidth: (_) => 24,
    );
  }

  static final routes = <GetPage>[
    _page(
      name: Routes.splash,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 400),
    ),
    _page(
      name: Routes.home,
      page: () => const HomeScreen(),
      bind: () {
        _ensureHomeController();
        // After home paints — never block splash/home on Hive/NLS.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _ensureNotificationController();
          } catch (e) {
            debugPrint('NotificationHistoryController skipped: $e');
          }
        });
      },
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 450),
    ),
    _page(
      name: Routes.storageAnalyzer,
      page: () => const StorageAnalyzerScreen(),
      bind: _ensureStorageController,
    ),
    _page(
      name: Routes.largeFiles,
      page: () => const LargeFilesScreen(),
      bind: _ensureStorageController,
    ),
    _page(
      name: Routes.duplicateFiles,
      page: () => const DuplicateFilesScreen(),
      bind: _ensureStorageController,
    ),
    _page(
      name: Routes.duplicateImages,
      page: () => const DuplicateImagesScreen(),
      bind: _ensureStorageController,
    ),
    _page(
      name: Routes.storageExplorer,
      page: () => const StorageExplorerScreen(),
      bind: _ensureStorageController,
    ),
    _page(
      name: Routes.videoDownloader,
      page: () => const VideoDownloaderScreen(),
      bind: () {
        Get.put(VideoDownloaderController());
      },
    ),
    _page(
      name: Routes.notificationHistory,
      page: () => const NotificationHistoryScreen(),
      bind: _ensureNotificationController,
    ),
    _page(
      name: Routes.notificationSettings,
      page: () => const NotificationSettingsScreen(),
      bind: _ensureNotificationController,
    ),
    _page(
      name: Routes.notificationApp,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        return AppNotificationsScreen(
          packageName: args['packageName']?.toString() ?? '',
          appName: args['appName']?.toString() ?? 'App',
          appColor: args['appColor'] as Color? ?? Colors.orangeAccent,
        );
      },
      bind: _ensureNotificationController,
    ),
    _page(
      name: Routes.notificationChat,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        return SenderConversationScreen(
          packageName: args['packageName']?.toString() ?? '',
          appName: args['appName']?.toString() ?? 'App',
          senderName: args['senderName']?.toString() ?? 'Unknown',
          appColor: args['appColor'] as Color? ?? Colors.orangeAccent,
        );
      },
      bind: _ensureNotificationController,
    ),
    _page(
      name: Routes.notes,
      page: () => const NotesScreen(),
      bind: () {
        Get.put(NotesController());
      },
    ),
    _page(
      name: Routes.unitConverter,
      page: () => const UnitConverterScreen(),
      bind: () {
        Get.put(UnitConverterController());
      },
    ),
    _page(
      name: Routes.clipboard,
      page: () => const ClipboardScreen(),
      bind: () {
        Get.put(ClipboardController());
      },
    ),
    _page(
      name: Routes.userProfile,
      page: () => const UserProfileScreen(),
      bind: () {
        Get.put(UserProfileController());
      },
    ),
  ];
}
