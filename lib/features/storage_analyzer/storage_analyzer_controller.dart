import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage_space/storage_space.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:crypto/crypto.dart';

class StorageAnalyzerController extends GetxController {
  final Rx<StorageSpace?> storageSpace = Rx<StorageSpace?>(null);
  final RxList<File> largeFiles = <File>[].obs;
  final RxList<List<AssetEntity>> duplicateImages = <List<AssetEntity>>[].obs;
  final RxDouble cacheSize = 0.0.obs; // in MB
  final RxDouble appSize = 0.0.obs; // in MB
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshData();
  }

  Future<void> refreshData() async {
    isLoading.value = true;
    await Future.wait([
      getStorageInfo(),
      getCacheSize(),
      getAppSize(),
    ]);
    isLoading.value = false;
  }

  Future<void> getStorageInfo() async {
    try {
      storageSpace.value = await getStorageSpace(
        lowOnSpaceThreshold: 2 * 1024 * 1024 * 1024, // 2GB
        fractionDigits: 1,
      );
    } catch (e) {
      Get.log('Error getting storage info: $e');
    }
  }

  Future<void> scanLargeFiles() async {
    isLoading.value = true;
    largeFiles.clear();
    
    if (await Permission.storage.request().isGranted || await Permission.manageExternalStorage.request().isGranted) {
      try {
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Go up to the root of accessible storage if possible, otherwise use this dir
          String rootPath = externalDir.path.split('/Android')[0];
          Directory root = Directory(rootPath);
          List<File> result = [];
          await _findLargeFiles(root, result);
          result.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
          largeFiles.assignAll(result.take(50)); // Top 50 large files
        }
      } catch (e) {
        Get.log('Error scanning large files: $e');
      }
    }
    isLoading.value = false;
  }

  Future<void> _findLargeFiles(Directory dir, List<File> result) async {
    try {
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          if (entity.lengthSync() > 10 * 1024 * 1024) { // > 10MB
            result.add(entity);
          }
        } else if (entity is Directory) {
          // Avoid restricted or system folders to prevent crashes/long waits
          if (!entity.path.contains('/.') && !entity.path.contains('Android/data')) {
            await _findLargeFiles(entity, result);
          }
        }
      }
    } catch (e) {
      // Ignore directory access errors
    }
  }

  Future<void> findDuplicateImages() async {
    isLoading.value = true;
    duplicateImages.clear();

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
      if (albums.isNotEmpty) {
        List<AssetEntity> allImages = await albums[0].getAssetListRange(start: 0, end: 500); // Limit for performance
        
        Map<String, List<AssetEntity>> hashGroups = {};
        
        for (var image in allImages) {
          File? file = await image.file;
          if (file != null) {
            String hash = await _calculateHash(file);
            if (hashGroups.containsKey(hash)) {
              hashGroups[hash]!.add(image);
            } else {
              hashGroups[hash] = [image];
            }
          }
        }
        
        duplicateImages.assignAll(hashGroups.values.where((group) => group.length > 1).toList());
      }
    }
    isLoading.value = false;
  }

  Future<String> _calculateHash(File file) async {
    // For performance, we can hash just the first 100KB + size
    try {
      int size = await file.length();
      var bytes = await file.openRead(0, 102400).first;
      return '$size-${md5.convert(bytes)}';
    } catch (e) {
      return '';
    }
  }

  Future<void> getCacheSize() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      int size = await _getDirSize(tempDir);
      cacheSize.value = size / (1024 * 1024);
    } catch (e) {
      Get.log('Error getting cache size: $e');
    }
  }

  Future<void> cleanCache() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }
      await getCacheSize();
    } catch (e) {
      Get.log('Error cleaning cache: $e');
    }
  }

  Future<void> getAppSize() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      int size = await _getDirSize(appDir);
      appSize.value = size / (1024 * 1024);
    } catch (e) {
      Get.log('Error getting app size: $e');
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (dir.existsSync()) {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
    } catch (e) {
      Get.log('Error calculating directory size: $e');
    }
    return totalSize;
  }
}
