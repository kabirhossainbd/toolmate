import 'package:get/get.dart';
import 'package:toolmate/features/notification_history/notification_history_controller.dart';
import 'package:toolmate/features/user_profile/user_profile_controller.dart';
import 'package:toolmate/features/user_profile/user_profile_screen.dart';
import 'app_routes.dart';
import '../features/home/home_screen.dart';
import '../features/home/home_controller.dart';
import '../features/storage_analyzer/storage_analyzer_screen.dart';
import '../features/storage_analyzer/storage_analyzer_controller.dart';
import '../features/video_downloader/video_downloader_screen.dart';
import '../features/video_downloader/video_downloader_controller.dart';
import '../features/notification_history/notification_history_screen.dart';

class AppPages {
  static const initial = Routes.home;

  static final routes = [
    GetPage(
      name: Routes.home,
      page: () => const HomeScreen(),
      binding: BindingsBuilder(() {
        Get.put(HomeController());
      }),
    ),
    GetPage(
      name: Routes.storageAnalyzer,
      page: () => const StorageAnalyzerScreen(),
      transition: Transition.cupertino,
      binding: BindingsBuilder(() {
        Get.put(StorageAnalyzerController());
      }),
    ),
    GetPage(
      name: Routes.videoDownloader,
      page: () => const VideoDownloaderScreen(),
      transition: Transition.cupertino,
      binding: BindingsBuilder(() {
        Get.put(VideoDownloaderController());
      }),
    ),
    GetPage(
      name: Routes.notificationHistory,
      page: () => const NotificationHistoryScreen(),
      transition: Transition.cupertino,
      binding: BindingsBuilder(() {
        Get.put(NotificationHistoryController());
      }),
    ),
    GetPage(
      name: Routes.userProfile,
      page: () => const UserProfileScreen(),
      transition: Transition.cupertino,
      binding: BindingsBuilder(() {
        Get.put(UserProfileController());
      }),
    ),
  ];
}
