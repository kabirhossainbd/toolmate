import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'core/background_service.dart';
import 'routes/app_pages.dart';
import 'features/video_downloader/video_model.dart';
import 'features/notification_history/notification_model.dart';
import 'features/user_profile/user_profile_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(VideoModelAdapter());
  Hive.registerAdapter(NotificationModelAdapter());
  Hive.registerAdapter(UserProfileModelAdapter());
  await Hive.openBox<VideoModel>('video_history');
  await Hive.openBox<NotificationModel>('notifications');
  await Hive.openBox<UserProfileModel>('user_profile');

  // Initialize Background Service
  await BackgroundService.initializeService();

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Toolmate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
