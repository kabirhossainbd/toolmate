/// Shared app-wide constants: Hive box names, branding, timing.
class AppConstants {
  AppConstants._();

  static const String appName = 'Toolmate';

  // ─── Hive box names ─────────────────────────────────────────────────────────
  static const String boxNotifications = 'notifications';
  static const String boxVideoHistory = 'video_history';
  static const String boxUserProfile = 'user_profile';
  static const String boxAppSettings = 'app_settings';
  static const String boxNotes = 'notes';
  static const String boxClipboard = 'clipboard_history';
  static const String boxFileVault = 'file_vault';

  // ─── Durations ──────────────────────────────────────────────────────────────
  static const Duration snackbarDuration = Duration(seconds: 3);
  static const Duration shortAnimation = Duration(milliseconds: 250);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  static const Duration debounce = Duration(milliseconds: 350);
  static const Duration splashDelay = Duration(milliseconds: 1200);
}
