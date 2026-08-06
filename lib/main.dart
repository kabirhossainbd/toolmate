import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/background_service.dart';
import 'core/constants/app_constants.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/settings/app_translations.dart';
import 'core/theme.dart';
import 'features/notification_history/notification_model.dart';
import 'features/user_profile/user_profile_model.dart';
import 'features/video_downloader/video_model.dart';
import 'routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(VideoModelAdapter());
  Hive.registerAdapter(NotificationModelAdapter());
  Hive.registerAdapter(UserProfileModelAdapter());

  await Future.wait([
    Hive.openBox<VideoModel>(AppConstants.boxVideoHistory),
    Hive.openBox<NotificationModel>(AppConstants.boxNotifications),
    Hive.openBox<UserProfileModel>(AppConstants.boxUserProfile),
    Hive.openBox(AppConstants.boxAppSettings),
    Hive.openBox(AppConstants.boxNotes),
    Hive.openBox(AppConstants.boxClipboard),
  ]);

  // Never block first frame on BG service — configure/start can hang when the
  // foreground service survived swipe-from-recents (stopWithTask=false).
  unawaited(
    BackgroundService.initializeService().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        // ignore: avoid_print
        print('BackgroundService.initializeService timed out');
      },
    ).catchError((Object e) {
      // ignore: avoid_print
      print('BackgroundService.initializeService failed: $e');
    }),
  );

  // Preferences before first frame
  Get.put(AppSettingsController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsController>();

    return Obx(
      () => GetMaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: settings.themeMode.value,
        translations: AppTranslations(),
        locale: settings.locale,
        fallbackLocale: const Locale('en', 'US'),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}
