import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/hive_bootstrap.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/settings/app_translations.dart';
import 'core/theme.dart';
import 'features/notification_history/notification_history_controller.dart';
import 'routes/app_pages.dart';

/// Starts the real UI after [main] has already painted a frame.
void start() {
  if (!Get.isRegistered<AppSettingsController>()) {
    Get.put(AppSettingsController(), permanent: true);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootHive());
    });
  }

  Future<void> _bootHive() async {
    try {
      await HiveBootstrap.init().timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('HiveBootstrap failed: $e');
    }
    if (Get.isRegistered<AppSettingsController>()) {
      Get.find<AppSettingsController>().reloadFromBox();
    }
    if (!Get.isRegistered<NotificationHistoryController>()) {
      Get.put(NotificationHistoryController(), permanent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsController>();

    // Do not wrap GetMaterialApp in Obx — rebuilding it resets navigation
    // back to the splash. Theme/locale updates go through Get.changeThemeMode
    // / Get.updateLocale.
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode.value,
      translations: AppTranslations(),
      locale: settings.locale,
      fallbackLocale: const Locale('en', 'US'),
      defaultTransition: Transition.native,
      transitionDuration: const Duration(milliseconds: 400),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
