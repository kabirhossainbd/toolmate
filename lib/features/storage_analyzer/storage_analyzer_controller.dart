import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:storage_space/storage_space.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';

class StorageAnalyzerController extends GetxController {
  final Rx<StorageSpace?> storageSpace = Rx<StorageSpace?>(null);
  final RxList<File> largeFiles = <File>[].obs;
  final RxList<List<AssetEntity>> duplicateImages = <List<AssetEntity>>[].obs;
  final RxList<List<File>> duplicateFilesList = <List<File>>[].obs;
  final RxDouble cacheSize = 0.0.obs; // in MB
  final RxDouble appSize = 0.0.obs; // in MB
  final RxBool isLoading = false.obs;
  final RxInt scanProgress = 0.obs;
  final RxInt totalToScan = 0.obs;
  final RxInt filesFound = 0.obs;
  final RxString scanStatus = ''.obs;
  final RxBool isScanningImages = false.obs;
  final RxBool isScanningLargeFiles = false.obs;
  final RxBool isScanningDuplicates = false.obs;
  final RxBool isScanningFolders = false.obs;

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
      final space = await getStorageSpace(
        lowOnSpaceThreshold: 2 * 1024 * 1024 * 1024, // 2GB
        fractionDigits: 1,
      );
      
      // Standardize total storage (e.g., 224.8GB -> 256GB)
      getStandardTotal(space.total);

      // Create a new StorageSpace-like object or just update the UI values.
      // Since StorageSpace is a class from a package, we'll keep the original
      // but the screen will handle the display logic for consistency.
      storageSpace.value = space;
        } catch (e) {
      Get.log('Error getting storage info: $e');
    }
  }

  int getStandardTotal(int totalBytes) {
    double totalGB = totalBytes / (1024 * 1024 * 1024);
    
    // Common storage sizes in GB
    List<int> standardSizes = [8, 16, 32, 64, 128, 256, 512, 1024];
    
    for (int size in standardSizes) {
      if (totalGB < size) {
        // If the reported size is close to a standard size (usually ~90% due to system partitions)
        if (totalGB > size * 0.8) {
          return size;
        }
      }
    }
    return totalGB.round();
  }

  Future<void> scanLargeFiles() async {
    isScanningLargeFiles.value = true;
    largeFiles.clear();
    scanProgress.value = 0;
    totalToScan.value = 0;
    filesFound.value = 0;
    scanStatus.value = 'Preparing to scan...';
    
    try {
      final manageGranted = await Permission.manageExternalStorage.isGranted;
      final storageGranted = await Permission.storage.isGranted;
      
      if (manageGranted || storageGranted) {
        Directory root = await _getPrimaryStorage();
        if (root.existsSync()) {
          scanStatus.value = 'Calculating total files...';
          int total = await _countFiles(root);
          totalToScan.value = total;
          
          List<File> result = [];
          await _findLargeFiles(root, result);
          result.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
          largeFiles.assignAll(result.take(50));
        }
      }
    } catch (e) {
      Get.log('Large Scan - Error: $e');
    } finally {
      isScanningLargeFiles.value = false;
      scanStatus.value = '';
    }
  }

  Future<int> _countFiles(Directory dir) async {
    int count = 0;
    try {
      if (!dir.existsSync()) return 0;
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          count++;
          if (count % 50 == 0) {
            filesFound.value = count;
            await Future.delayed(Duration.zero);
          }
        } else if (entity is Directory) {
          String path = entity.path.toLowerCase();
          if (!path.contains('/.') && !path.contains('/android') && !path.contains('/obb')) {
            count += await _countFiles(entity);
          }
        }
      }
      filesFound.value = count; // Final update for this folder
    } catch (e) {}
    return count;
  }

  Future<void> _findLargeFiles(Directory dir, List<File> result) async {
    try {
      if (!dir.existsSync()) return;
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          scanStatus.value = 'Scanning: ${entity.path.split('/').last}';
          scanProgress.value++;
          
          // Yield occasionally to keep UI responsive
          if (scanProgress.value % 50 == 0) {
            await Future.delayed(Duration.zero);
          }
          
          try {
            if (await entity.length() > 10 * 1024 * 1024) { // > 10MB
              result.add(entity);
            }
          } catch (e) {}
        } else if (entity is Directory) {
          String path = entity.path.toLowerCase();
          if (!path.contains('/.') && !path.contains('/android') && !path.contains('/obb')) {
            await _findLargeFiles(entity, result);
          }
        }
      }
    } catch (e) {}
  }

  Future<void> findAllDuplicateFiles() async {
    isScanningDuplicates.value = true;
    duplicateFilesList.clear();
    scanProgress.value = 0;
    totalToScan.value = 0;
    filesFound.value = 0;
    scanStatus.value = 'Preparing to scan...';

    try {
      final manageGranted = await Permission.manageExternalStorage.isGranted;
      final storageGranted = await Permission.storage.isGranted;

      if (manageGranted || storageGranted) {
        Directory root = await _getPrimaryStorage();
        if (root.existsSync()) {
          scanStatus.value = 'Calculating total files...';
          int total = await _countFiles(root);
          totalToScan.value = total;
          
          Map<int, List<File>> sizeGroups = {};
          await _groupFilesBySize(root, sizeGroups);

          Get.log('Duplicate Scan - Size groups: ${sizeGroups.length}');
          
          List<File> candidates = [];
          sizeGroups.values.forEach((list) {
            if (list.length > 1) {
              for (var file in list) {
                try {
                  if (file.lengthSync() > 50 * 1024) {
                    candidates.add(file);
                  }
                } catch (e) {}
              }
            }
          });
          
          Get.log('Duplicate Scan - Candidates: ${candidates.length}');
          totalToScan.value = candidates.length;
          scanProgress.value = 0;
          
          Map<String, List<File>> hashGroups = {};
          for (var i = 0; i < candidates.length; i++) {
            File file = candidates[i];
            scanStatus.value = 'Comparing: ${file.path.split('/').last}';
            scanProgress.value = i + 1;
            
            // Critical yield to prevent UI freeze during hashing
            await Future.delayed(Duration.zero);
            
            String hash = await _calculateHash(file);
            if (hash != '') {
              hashGroups.putIfAbsent(hash, () => []).add(file);
            }
          }
          
          duplicateFilesList.assignAll(
            hashGroups.values.where((group) => group.length > 1).toList()
          );
        }
      }
    } catch (e) {
      Get.log('Duplicate Scan - Error: $e');
    } finally {
      isScanningDuplicates.value = false;
      scanStatus.value = '';
    }
  }

  Future<Directory> _getPrimaryStorage() async {
    Directory root = Directory('/storage/emulated/0');
    if (root.existsSync()) return root;
    
    try {
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        String path = externalDirs[0].path;
        int androidIndex = path.indexOf('/Android');
        if (androidIndex != -1) {
          return Directory(path.substring(0, androidIndex));
        }
      }
    } catch (e) {}
    return root; 
  }

  Future<void> _groupFilesBySize(Directory dir, Map<int, List<File>> groups) async {
    try {
      if (!dir.existsSync()) return;
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          try {
            int size = await entity.length();
            if (size > 0) {
              groups.putIfAbsent(size, () => []).add(entity);
            }
          } catch (e) {}
        } else if (entity is Directory) {
          String path = entity.path.toLowerCase();
          if (!path.contains('/.') && 
              !path.contains('/android/data') && 
              !path.contains('/android/obb')) {
            await _groupFilesBySize(entity, groups);
          }
        }
      }
    } catch (e) {}
  }



  Future<void> findDuplicateImages() async {
    isScanningImages.value = true;
    duplicateImages.clear();
    scanProgress.value = 0;
    totalToScan.value = 0;
    scanStatus.value = 'Accessing gallery...';

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth) {
        List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
        List<AssetEntity> allImages = [];
        
        for (var album in albums) {
          int count = await album.assetCountAsync;
          List<AssetEntity> albumAssets = await album.getAssetListRange(start: 0, end: count);
          allImages.addAll(albumAssets);
        }
        
        totalToScan.value = allImages.length;
        scanProgress.value = 0;
        
        Map<String, List<AssetEntity>> hashGroups = {};
        
        for (var i = 0; i < allImages.length; i++) {
          AssetEntity image = allImages[i];
          scanStatus.value = 'Analyzing: ${image.title ?? 'Image ${i + 1}'}';
          scanProgress.value = i + 1;
          
          // Yield to keep UI smooth
          await Future.delayed(Duration.zero);
          
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
    } catch (e) {
      Get.log('Error scanning duplicate images: $e');
    } finally {
      isScanningImages.value = false;
      scanStatus.value = '';
    }
  }

  Future<String> _calculateHash(File file) async {
    try {
      int size = await file.length();
      // For performance, hash first 64KB + last 64KB + size
      var raf = await file.open();
      var head = await raf.read(64 * 1024);
      
      List<int> combined;
      if (size > 128 * 1024) {
        await raf.setPosition(size - 64 * 1024);
        var tail = await raf.read(64 * 1024);
        combined = [...head, ...tail];
      } else {
        combined = head;
      }
      await raf.close();
      
      return '$size-${md5.convert(combined)}';
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

  Future<void> deleteAsset(AssetEntity asset) async {
    try {
      final List<String> result = await PhotoManager.editor.deleteWithIds([asset.id]);
      if (result.isNotEmpty) {
        // Asset deleted successfully
      } else {
        throw Exception('Failed to delete asset');
      }
    } catch (e) {
      Get.log('Error deleting asset: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (e) {
      Get.log('Error deleting file: $e');
      rethrow;
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

  final RxList<FileSystemEntityInfo> currentFolderContent = <FileSystemEntityInfo>[].obs;
  final RxString currentPath = '/storage/emulated/0'.obs;

  Future<void> listFolderContent(String path) async {
    currentPath.value = path;
    isScanningFolders.value = true;
    currentFolderContent.clear();
    
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final List<FileSystemEntityInfo> items = [];
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          final name = entity.path.split('/').last;
          if (name.startsWith('.')) continue;

          if (entity is Directory) {
            // For directories, calculate size asynchronously in background
            items.add(FileSystemEntityInfo(
              name: name,
              path: entity.path,
              isFolder: true,
              size: 0, // Will be updated if needed or just shown as "Folder"
              itemCount: 0,
            ));
          } else if (entity is File) {
            final size = await entity.length();
            items.add(FileSystemEntityInfo(
              name: name,
              path: entity.path,
              isFolder: false,
              size: size,
              extension: name.split('.').last.toLowerCase(),
            ));
          }
        }
        
        // Sort: Folders first, then Files by name
        items.sort((a, b) {
          if (a.isFolder && !b.isFolder) return -1;
          if (!a.isFolder && b.isFolder) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        
        currentFolderContent.assignAll(items);
        
        // Optional: Update folder sizes in background
        for (var i = 0; i < currentFolderContent.length; i++) {
          if (currentFolderContent[i].isFolder) {
            _updateFolderSize(i);
          }
        }
      }
    } catch (e) {
      Get.log('Error listing folder content: $e');
    } finally {
      isScanningFolders.value = false;
    }
  }

  Future<void> _updateFolderSize(int index) async {
    try {
      final item = currentFolderContent[index];
      final dir = Directory(item.path);
      int size = 0;
      int count = 0;
      
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          size += await entity.length();
          count++;
        } else {
          count++;
        }
        // Yield for UI
        if (count % 100 == 0) await Future.delayed(Duration.zero);
      }
      
      currentFolderContent[index] = item.copyWith(size: size, itemCount: count);
    } catch (e) {}
  }

  Future<void> deleteFileSystemEntity(String path) async {
    try {
      final entity = FileSystemEntity.isFileSync(path) ? File(path) : Directory(path);
      if (await entity.exists()) {
        await entity.delete(recursive: true);
        // Refresh current folder
        await listFolderContent(currentPath.value);
      }
    } catch (e) {
      Get.log('Error deleting entity: $e');
      rethrow;
    }
  }

  String formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(1)) + ' ' + suffixes[i];
  }
}

class FileSystemEntityInfo {
  final String name;
  final String path;
  final bool isFolder;
  final int size;
  final int itemCount;
  final String? extension;

  FileSystemEntityInfo({
    required this.name,
    required this.path,
    required this.isFolder,
    required this.size,
    this.itemCount = 0,
    this.extension,
  });

  FileSystemEntityInfo copyWith({int? size, int? itemCount}) {
    return FileSystemEntityInfo(
      name: name,
      path: path,
      isFolder: isFolder,
      size: size ?? this.size,
      itemCount: itemCount ?? this.itemCount,
      extension: extension,
    );
  }
}
