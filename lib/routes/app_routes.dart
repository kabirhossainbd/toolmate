/// Route names for shipped features only.
abstract class Routes {
  static const initial = '/';
  static const splash = '/';
  static const home = '/home';

  static const storageAnalyzer = '/storage-analyzer';
  // Sibling routes — never nest as `/storage-analyzer/...` or GetX
  // creates a nested navigator that traps back navigation.
  static const largeFiles = '/large-files';
  static const duplicateFiles = '/duplicate-files';
  static const duplicateImages = '/duplicate-images';
  static const storageExplorer = '/storage-explorer';
  static const videoDownloader = '/video-downloader';
  static const notificationHistory = '/notification-history';
  static const notificationSettings = '/notification-settings';
  static const notificationApp = '/notification-app';
  static const notificationChat = '/notification-chat';
  static const userProfile = '/user-profile';

  static const notes = '/notes';
  static const unitConverter = '/unit-converter';
  static const clipboard = '/clipboard';
}
