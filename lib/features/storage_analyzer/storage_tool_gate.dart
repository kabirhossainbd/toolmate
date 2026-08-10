import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// Waits until the current route push animation finishes (or is already done).
/// Keeps heavy work off the transition so it stays butter-smooth.
Future<void> waitForRouteTransition(BuildContext context) async {
  final animation = ModalRoute.of(context)?.animation;
  if (animation == null || animation.status == AnimationStatus.completed) {
    return;
  }
  final done = Completer<void>();
  void listener(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    animation.removeStatusListener(listener);
    if (!done.isCompleted) done.complete();
  }

  animation.addStatusListener(listener);
  await Future.any([
    done.future,
    Future<void>.delayed(const Duration(milliseconds: 500)),
  ]);
  animation.removeStatusListener(listener);
}

/// Runs after a tool screen is already visible — never block Get.to / Get.toNamed.
Future<bool> ensureStorageToolAccess({
  required String title,
  required String message,
  bool gallery = false,
}) async {
  if (gallery) {
    final status = await PhotoManager.requestPermissionExtend();
    if (status.isAuth) return true;
  } else {
    final manage = await Permission.manageExternalStorage.isGranted;
    final storage = await Permission.storage.isGranted;
    if (manage || storage) return true;
  }

  final granted = await Get.dialog<bool>(
    Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (gallery ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                gallery
                    ? Icons.photo_library_rounded
                    : Icons.folder_shared_rounded,
                color: gallery ? Colors.green : Colors.blue,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(result: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Not Now'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (gallery) {
                        final status =
                            await PhotoManager.requestPermissionExtend();
                        Get.back(result: status.isAuth);
                      } else {
                        var status =
                            await Permission.manageExternalStorage.request();
                        if (!status.isGranted) {
                          status = await Permission.storage.request();
                        }
                        Get.back(result: status.isGranted);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gallery ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Grant Access'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    barrierDismissible: false,
  );

  return granted == true;
}
