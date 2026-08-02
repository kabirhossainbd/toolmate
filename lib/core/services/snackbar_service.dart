import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_constants.dart';

/// Thin wrappers around [Get.snackbar] for consistent feedback.
class SnackbarService {
  SnackbarService._();

  static void success(String title, {String? message}) {
    Get.snackbar(
      title,
      message ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: AppConstants.snackbarDuration,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
    );
  }

  static void error(String title, {String? message}) {
    Get.snackbar(
      title,
      message ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: AppConstants.snackbarDuration,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  static void info(String title, {String? message}) {
    Get.snackbar(
      title,
      message ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blueGrey.shade700,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: AppConstants.snackbarDuration,
      icon: const Icon(Icons.info_outline, color: Colors.white),
    );
  }
}
