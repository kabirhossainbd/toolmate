import 'dart:io';

import 'package:flutter/services.dart';

/// Loads an app icon for a known package name (notification history).
/// Does not enumerate installed apps and does not need QUERY_ALL_PACKAGES.
class AppIconResolver {
  AppIconResolver._();

  static const _channel = MethodChannel('toolmate/app_info');

  static Future<Uint8List?> getIcon(String packageName) async {
    if (!Platform.isAndroid || packageName.isEmpty) return null;
    try {
      return await _channel.invokeMethod<Uint8List>('getAppIcon', {
        'packageName': packageName,
      });
    } catch (_) {
      return null;
    }
  }
}
