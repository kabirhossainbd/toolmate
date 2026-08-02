import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../constants/app_constants.dart';

/// Persisted app preferences: theme + language.
class AppSettingsController extends GetxController {
  static const _keyTheme = 'theme_mode';
  static const _keyLocale = 'locale_code';

  late final Box _box;

  final themeMode = ThemeMode.system.obs;
  final localeCode = 'en'.obs;

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
    _box = Hive.box(AppConstants.boxAppSettings);
    _load();
  }

  void _load() {
    final themeRaw = _box.get(_keyTheme, defaultValue: 'system') as String;
    themeMode.value = switch (themeRaw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    localeCode.value = (_box.get(_keyLocale, defaultValue: 'en') as String);
    _applyTheme();
    _applyLocale();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    final key = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    _box.put(_keyTheme, key);
    _applyTheme();
  }

  void setLocaleCode(String code) {
    if (code != 'en' && code != 'bn') return;
    localeCode.value = code;
    _box.put(_keyLocale, code);
    _applyLocale();
  }

  void _applyTheme() {
    Get.changeThemeMode(themeMode.value);
  }

  void _applyLocale() {
    Get.updateLocale(locale);
  }
}
