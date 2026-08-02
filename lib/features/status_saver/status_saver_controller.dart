import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class StatusItem {
  final File file;
  final bool isVideo;

  const StatusItem({required this.file, required this.isVideo});
}

class StatusSaverController extends GetxController {
  static const _statusPaths = [
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses',
  ];

  static const _saveDirPath = '/storage/emulated/0/Pictures/ToolmateStatuses';

  final RxList<StatusItem> statuses = <StatusItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool folderMissing = false.obs;
  final RxString sourcePath = ''.obs;
  final RxSet<String> selected = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshStatuses();
  }

  Future<bool> _ensureStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted) {
      return true;
    }
    final manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<void> refreshStatuses() async {
    isLoading.value = true;
    folderMissing.value = false;
    statuses.clear();
    selected.clear();
    sourcePath.value = '';

    try {
      await _ensureStoragePermission();

      Directory? found;
      for (final path in _statusPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          found = dir;
          break;
        }
      }

      if (found == null) {
        folderMissing.value = true;
        return;
      }

      sourcePath.value = found.path;
      final items = <StatusItem>[];

      await for (final entity in found.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path).toLowerCase();
        if (name.startsWith('.')) continue;

        final isImage = name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.png') ||
            name.endsWith('.webp');
        final isVideo = name.endsWith('.mp4') ||
            name.endsWith('.3gp') ||
            name.endsWith('.mkv');

        if (isImage || isVideo) {
          items.add(StatusItem(file: entity, isVideo: isVideo));
        }
      }

      items.sort(
        (a, b) =>
            b.file.lastModifiedSync().compareTo(a.file.lastModifiedSync()),
      );
      statuses.assignAll(items);
    } catch (e) {
      folderMissing.value = true;
      Get.log('StatusSaver scan error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void toggleSelect(String path) {
    if (selected.contains(path)) {
      selected.remove(path);
    } else {
      selected.add(path);
    }
  }

  void selectAll() {
    selected.assignAll(statuses.map((s) => s.file.path));
  }

  void clearSelection() => selected.clear();

  Future<void> saveSelected() async {
    final paths = selected.isEmpty
        ? statuses.map((s) => s.file.path).toList()
        : selected.toList();

    if (paths.isEmpty) {
      Get.snackbar('Status Saver', 'Nothing to save');
      return;
    }

    try {
      await _ensureStoragePermission();
      final destDir = Directory(_saveDirPath);
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      var saved = 0;
      for (final path in paths) {
        final source = File(path);
        if (!await source.exists()) continue;
        final dest = File(p.join(destDir.path, p.basename(path)));
        await source.copy(dest.path);
        saved++;
      }

      Get.snackbar(
        'Status Saver',
        saved > 0
            ? 'Saved $saved file(s) to Pictures/ToolmateStatuses'
            : 'No files saved',
      );
      clearSelection();
    } catch (e) {
      Get.snackbar('Status Saver', 'Save failed: $e');
    }
  }
}
