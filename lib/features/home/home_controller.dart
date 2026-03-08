import 'package:get/get.dart';
import '../../routes/app_routes.dart';

class HomeController extends GetxController {
  void navigateToStorageAnalyzer() {
    Get.toNamed(Routes.storageAnalyzer);
  }

  void navigateToVideoDownloader() {
    Get.toNamed(Routes.videoDownloader);
  }

  void navigateToNotificationHistory() {
    Get.toNamed(Routes.notificationHistory);
  }

  void navigateToUserProfile() {
    Get.toNamed(Routes.userProfile);
  }
}
