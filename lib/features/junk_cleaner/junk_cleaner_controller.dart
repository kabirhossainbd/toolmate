import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class JunkCleanerController extends GetxController {
  final RxInt tempBytes = 0.obs;
  final RxInt cacheBytes = 0.obs;
  final RxBool isScanning = false.obs;
  final RxBool isCleaning = false.obs;

  int get totalBytes => tempBytes.value + cacheBytes.value;

  @override
  void onInit() {
    super.onInit();
    scan();
  }

  Future<void> scan() async {
    isScanning.value = true;
    try {
      final tempDir = await getTemporaryDirectory();
      tempBytes.value = await _dirSize(tempDir);

      try {
        final cacheDir = await getApplicationCacheDirectory();
        cacheBytes.value = await _dirSize(cacheDir);
      } catch (_) {
        cacheBytes.value = 0;
      }
    } catch (e) {
      Get.snackbar('Junk Cleaner', 'Scan failed: $e');
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> clean() async {
    isCleaning.value = true;
    try {
      final tempDir = await getTemporaryDirectory();
      await _clearDirectory(tempDir);

      try {
        final cacheDir = await getApplicationCacheDirectory();
        await _clearDirectory(cacheDir);
      } catch (_) {}

      await scan();
      Get.snackbar('Junk Cleaner', 'Cleanup complete');
    } catch (e) {
      Get.snackbar('Junk Cleaner', 'Clean failed: $e');
    } finally {
      isCleaning.value = false;
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {}
    }
  }

  String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = min(suffixes.length - 1, (log(bytes) / log(1024)).floor());
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
