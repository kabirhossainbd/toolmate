import 'dart:io';

import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageToolsController extends GetxController {
  final ImagePicker _picker = ImagePicker();

  final Rx<File?> originalFile = Rx<File?>(null);
  final Rx<File?> compressedFile = Rx<File?>(null);
  final RxInt originalBytes = 0.obs;
  final RxInt compressedBytes = 0.obs;
  final RxBool isWorking = false.obs;
  final RxString savedPath = ''.obs;

  Future<void> pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      originalFile.value = file;
      originalBytes.value = await file.length();
      compressedFile.value = null;
      compressedBytes.value = 0;
      savedPath.value = '';
    } catch (e) {
      Get.snackbar('Image Tools', 'Could not pick image: $e');
    }
  }

  Future<void> compress({int quality = 70}) async {
    final source = originalFile.value;
    if (source == null) {
      Get.snackbar('Image Tools', 'Pick an image first');
      return;
    }

    isWorking.value = true;
    try {
      final bytes = await source.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        Get.snackbar('Image Tools', 'Unsupported image format');
        return;
      }

      final encoded = img.encodeJpg(decoded, quality: quality);
      compressedBytes.value = encoded.length;

      final temp = await getTemporaryDirectory();
      final out = File(
        p.join(
          temp.path,
          'toolmate_compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      await out.writeAsBytes(encoded, flush: true);
      compressedFile.value = out;
    } catch (e) {
      Get.snackbar('Image Tools', 'Compress failed: $e');
    } finally {
      isWorking.value = false;
    }
  }

  Future<void> saveResult() async {
    final file = compressedFile.value ?? originalFile.value;
    if (file == null) {
      Get.snackbar('Image Tools', 'Nothing to save');
      return;
    }

    isWorking.value = true;
    try {
      bool? saved;
      try {
        saved = await GallerySaver.saveImage(file.path);
      } catch (_) {
        saved = null;
      }

      if (saved == true) {
        savedPath.value = 'Saved to gallery';
        Get.snackbar('Image Tools', 'Saved to gallery');
        return;
      }

      final docs = await getApplicationDocumentsDirectory();
      final destDir = Directory(p.join(docs.path, 'image_tools'));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      final dest = File(
        p.join(
          destDir.path,
          'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );
      await file.copy(dest.path);
      savedPath.value = dest.path;
      Get.snackbar('Image Tools', 'Saved to app folder');
    } catch (e) {
      Get.snackbar('Image Tools', 'Save failed: $e');
    } finally {
      isWorking.value = false;
    }
  }

  String formatSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  double get savingsPercent {
    if (originalBytes.value <= 0 || compressedBytes.value <= 0) return 0;
    final saved = originalBytes.value - compressedBytes.value;
    if (saved <= 0) return 0;
    return (saved / originalBytes.value) * 100;
  }
}
