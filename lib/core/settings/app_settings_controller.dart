import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';

/// Persisted app preferences: theme, language, and notification history.
class AppSettingsController extends GetxController {
  static const _keyTheme = 'theme_mode';
  static const _keyLocale = 'locale_code';
  static const _keyGroupNotifs = 'notif_group';
  static const _keyHistoryDisabled = 'notif_history_disabled';
  static const _keySaveOngoing = 'notif_save_ongoing';
  static const _keyHistorySize = 'notif_history_size';
  static const _keyAutoDeleteDays = 'notif_auto_delete_days';

  /// 0 = unlimited. Used as the max stored/displayed notification count.
  static const historySizeOptions = [100, 500, 1000, 0];
  static const autoDeleteDayOptions = [0, 7, 30, 90];

  Box? _box;

  final themeMode = ThemeMode.system.obs;
  final localeCode = 'en'.obs;

  /// Group the history list by app. Off = flat list, tap opens a sheet.
  final groupNotifications = true.obs;
  final historyDisabled = false.obs;
  final saveOngoingNotifications = false.obs;
  /// 0 = unlimited.
  final historySize = 0.obs;
  /// 0 = never auto-delete.
  final autoDeleteDays = 0.obs;

  Locale get locale =>
      localeCode.value == 'bn' ? const Locale('bn', 'BD') : const Locale('en', 'US');

  String get themeLabel {
    switch (themeMode.value) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String get languageLabel => localeCode.value == 'bn' ? 'বাংলা' : 'English';

  @override
  void onInit() {
    super.onInit();
    reloadFromBox();
  }

  /// Re-read prefs after Hive opens (startup must not wait on the box).
  void reloadFromBox() {
    if (Hive.isBoxOpen(AppConstants.boxAppSettings)) {
      _box = Hive.box(AppConstants.boxAppSettings);
    }
    _load();
  }

  void _load() {
    final box = _box;
    final themeRaw =
        (box?.get(_keyTheme, defaultValue: 'system') ?? 'system') as String;
    themeMode.value = switch (themeRaw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    localeCode.value =
        (box?.get(_keyLocale, defaultValue: 'en') ?? 'en') as String;

    groupNotifications.value =
        (box?.get(_keyGroupNotifs, defaultValue: true) ?? true) as bool;
    historyDisabled.value =
        (box?.get(_keyHistoryDisabled, defaultValue: false) ?? false) as bool;
    saveOngoingNotifications.value =
        (box?.get(_keySaveOngoing, defaultValue: false) ?? false) as bool;
    historySize.value =
        (box?.get(_keyHistorySize, defaultValue: 0) ?? 0) as int;
    autoDeleteDays.value =
        (box?.get(_keyAutoDeleteDays, defaultValue: 0) ?? 0) as int;
  }

  String historySizeLabel() {
    final n = historySize.value;
    return n <= 0 ? 'Unlimited' : '$n';
  }

  String autoDeleteLabel() {
    switch (autoDeleteDays.value) {
      case 7:
        return 'After 7 days';
      case 30:
        return 'After 30 days';
      case 90:
        return 'After 90 days';
      default:
        return 'Never';
    }
  }

  void setGroupNotifications(bool value) {
    groupNotifications.value = value;
    _box?.put(_keyGroupNotifs, value);
  }

  void setHistoryDisabled(bool value) {
    historyDisabled.value = value;
    _box?.put(_keyHistoryDisabled, value);
  }

  void setSaveOngoingNotifications(bool value) {
    saveOngoingNotifications.value = value;
    _box?.put(_keySaveOngoing, value);
  }

  void setHistorySize(int value) {
    historySize.value = value;
    _box?.put(_keyHistorySize, value);
  }

  void setAutoDeleteDays(int days) {
    autoDeleteDays.value = days;
    _box?.put(_keyAutoDeleteDays, days);
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    final key = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    _box?.put(_keyTheme, key);
    _applyTheme();
  }

  void setLocaleCode(String code) {
    if (code != 'en' && code != 'bn') return;
    localeCode.value = code;
    _box?.put(_keyLocale, code);
    _applyLocale();
  }

  void _applyTheme() {
    Get.changeThemeMode(themeMode.value);
  }

  void _applyLocale() {
    Get.updateLocale(locale);
  }
}
