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

  /// Shared scan UI — percent 0–100; indeterminate while counting/walking dirs.
  final RxDouble scanPercent = 0.0.obs;
  final RxBool scanIndeterminate = true.obs;

  /// Canonical file path for each gallery asset id (used to avoid false duplicates).
  final Map<String, String> _imagePathById = {};

  /// Normalize Android path aliases + resolve symlinks so the same file
  /// is never treated as two different files.
  String _canonicalPath(String path) {
    var p = path.trim();
    if (p.startsWith('/sdcard')) {
      p = p.replaceFirst('/sdcard', '/storage/emulated/0');
    }
    if (p.startsWith('/storage/self/primary')) {
      p = p.replaceFirst('/storage/self/primary', '/storage/emulated/0');
    }
    if (p.startsWith('/mnt/sdcard')) {
      p = p.replaceFirst('/mnt/sdcard', '/storage/emulated/0');
    }
    // Collapse duplicate slashes
    p = p.replaceAll(RegExp(r'/+'), '/');
    try {
      return File(p).resolveSymbolicLinksSync();
    } catch (_) {
      return p;
    }
  }

  void _resetScanUi({required String status}) {
    scanProgress.value = 0;
    totalToScan.value = 0;
    filesFound.value = 0;
    scanPercent.value = 0;
    scanIndeterminate.value = true;
    scanStatus.value = status;
  }

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
    _resetScanUi(status: 'Scanning storage…');

    try {
      final manageGranted = await Permission.manageExternalStorage.isGranted;
      final storageGranted = await Permission.storage.isGranted;

      if (!(manageGranted || storageGranted)) {
        scanStatus.value = 'Storage permission required';
        return;
      }

      final root = await _getPrimaryStorage();
      if (!root.existsSync()) {
        scanStatus.value = 'Storage not available';
        return;
      }

      final result = <File>[];
      var scanned = 0;
      // Soft progress — storage walks have unknown size; climb toward 92%.
      scanIndeterminate.value = false;
      scanPercent.value = 2;

      await _findLargeFiles(root, result, onFile: () async {
        scanned++;
        filesFound.value = scanned;
        if (scanned % 30 == 0) {
          scanPercent.value = (2 + (scanned / (scanned + 400)) * 90).clamp(2, 92);
          scanStatus.value = 'Found ${result.length} large · checked $scanned';
          await Future.delayed(Duration.zero);
        }
      });

      result.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
      largeFiles.assignAll(result.take(50));
      scanPercent.value = 100;
      scanStatus.value = 'Done';
    } catch (e) {
      Get.log('Large Scan - Error: $e');
      scanStatus.value = 'Scan failed';
    } finally {
      isScanningLargeFiles.value = false;
    }
  }

  Future<void> _findLargeFiles(
    Directory dir,
    List<File> result, {
    Future<void> Function()? onFile,
  }) async {
    try {
      if (!dir.existsSync()) return;
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          try {
            if (await entity.length() > 10 * 1024 * 1024) {
              result.add(entity);
            }
          } catch (_) {}
          if (onFile != null) await onFile();
        } else if (entity is Directory) {
          final path = entity.path.toLowerCase();
          if (!path.contains('/.') &&
              !path.contains('/android') &&
              !path.contains('/obb')) {
            await _findLargeFiles(entity, result, onFile: onFile);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> findAllDuplicateFiles() async {
    isScanningDuplicates.value = true;
    duplicateFilesList.clear();
    _resetScanUi(status: 'Scanning storage…');

    try {
      final manageGranted = await Permission.manageExternalStorage.isGranted;
      final storageGranted = await Permission.storage.isGranted;

      if (!(manageGranted || storageGranted)) {
        scanStatus.value = 'Storage permission required';
        return;
      }

      final root = await _getPrimaryStorage();
      if (!root.existsSync()) {
        scanStatus.value = 'Storage not available';
        return;
      }

      // One entry per real path while indexing by size.
      final sizeGroups = <int, List<File>>{};
      final seenPaths = <String>{};
      var scanned = 0;
      scanIndeterminate.value = false;
      scanPercent.value = 3;
      scanStatus.value = 'Indexing files…';

      await _groupFilesBySize(root, sizeGroups, seenPaths, onFile: () async {
        scanned++;
        filesFound.value = scanned;
        if (scanned % 40 == 0) {
          scanPercent.value =
              (3 + (scanned / (scanned + 500)) * 40).clamp(3, 43);
          scanStatus.value = 'Indexed $scanned files…';
          await Future.delayed(Duration.zero);
        }
      });

      final candidates = <File>[];
      for (final list in sizeGroups.values) {
        if (list.length < 2) continue;
        for (final file in list) {
          try {
            if (await file.length() > 50 * 1024) {
              candidates.add(file);
            }
          } catch (_) {}
        }
      }

      if (candidates.isEmpty) {
        scanPercent.value = 100;
        scanStatus.value = 'No candidates';
        duplicateFilesList.clear();
        return;
      }

      scanStatus.value = 'Comparing ${candidates.length} files…';
      final quickGroups = <String, List<File>>{};
      for (var i = 0; i < candidates.length; i++) {
        final file = candidates[i];
        scanPercent.value = 43 + ((i + 1) / candidates.length * 40);
        if (i % 6 == 0) {
          scanStatus.value = 'Comparing: ${file.path.split('/').last}';
          await Future.delayed(Duration.zero);
        }
        final hash = await _quickHash(file);
        if (hash.isNotEmpty) {
          quickGroups.putIfAbsent(hash, () => []).add(file);
        }
      }

      // Confirm with full hash — drops false partial matches.
      scanStatus.value = 'Verifying duplicates…';
      final confirmed = <List<File>>[];
      final pending = quickGroups.values.where((g) => g.length > 1).toList();
      for (var gi = 0; gi < pending.length; gi++) {
        scanPercent.value = 83 + ((gi + 1) / pending.length * 17);
        final verified = await _verifyFileDuplicateGroup(pending[gi]);
        if (verified.length > 1) confirmed.add(verified);
        if (gi % 2 == 0) await Future.delayed(Duration.zero);
      }

      duplicateFilesList.assignAll(confirmed);
      scanPercent.value = 100;
      scanStatus.value = confirmed.isEmpty
          ? 'No true duplicates'
          : 'Found ${confirmed.length} groups';
    } catch (e) {
      Get.log('Duplicate Scan - Error: $e');
      scanStatus.value = 'Scan failed';
    } finally {
      isScanningDuplicates.value = false;
    }
  }

  /// Keep only files that truly share identical bytes, on different paths.
  Future<List<File>> _verifyFileDuplicateGroup(List<File> files) async {
    final byPath = <String, File>{};
    for (final f in files) {
      byPath.putIfAbsent(_canonicalPath(f.path), () => f);
    }
    if (byPath.length < 2) return [];

    final byFull = <String, List<File>>{};
    for (final f in byPath.values) {
      if (!f.existsSync()) continue;
      final h = await _fullHash(f);
      if (h.isEmpty) continue;
      byFull.putIfAbsent(h, () => []).add(f);
    }

    // Return the largest verified identical set (usually one).
    List<File> best = [];
    for (final g in byFull.values) {
      final unique = <String, File>{};
      for (final f in g) {
        unique[_canonicalPath(f.path)] = f;
      }
      if (unique.length > best.length) best = unique.values.toList();
    }
    return best.length > 1 ? best : [];
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

  Future<void> _groupFilesBySize(
    Directory dir,
    Map<int, List<File>> groups,
    Set<String> seenPaths, {
    Future<void> Function()? onFile,
  }) async {
    try {
      if (!dir.existsSync()) return;
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          try {
            final canon = _canonicalPath(entity.path);
            if (!seenPaths.add(canon)) {
              if (onFile != null) await onFile();
              continue;
            }
            final size = await entity.length();
            if (size > 0) {
              groups.putIfAbsent(size, () => []).add(File(canon));
            }
          } catch (_) {}
          if (onFile != null) await onFile();
        } else if (entity is Directory) {
          final path = entity.path.toLowerCase();
          if (!path.contains('/.') &&
              !path.contains('/android/data') &&
              !path.contains('/android/obb')) {
            await _groupFilesBySize(entity, groups, seenPaths, onFile: onFile);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> findDuplicateImages() async {
    isScanningImages.value = true;
    duplicateImages.clear();
    _imagePathById.clear();
    _resetScanUi(status: 'Accessing gallery…');

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) {
        scanStatus.value = 'Gallery permission required';
        return;
      }

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (albums.isEmpty) {
        scanPercent.value = 100;
        return;
      }

      final album = albums.first;
      final count = await album.assetCountAsync;
      final allImages = <AssetEntity>[];
      const pageSize = 80;
      scanIndeterminate.value = false;
      for (var start = 0; start < count; start += pageSize) {
        final end = (start + pageSize).clamp(0, count);
        final page = await album.getAssetListRange(start: start, end: end);
        allImages.addAll(page);
        filesFound.value = allImages.length;
        scanPercent.value =
            count == 0 ? 8 : (allImages.length / count * 25).clamp(0, 25);
        scanStatus.value = 'Loading gallery… ${allImages.length}/$count';
        await Future.delayed(Duration.zero);
      }

      // Unique by MediaStore id first.
      final byId = <String, AssetEntity>{};
      for (final img in allImages) {
        byId.putIfAbsent(img.id, () => img);
      }
      final uniqueImages = byId.values.toList();

      // Resolve each asset to ONE canonical disk path. Same photo under
      // multiple ids/aliases collapses to a single entry.
      final byPath = <String, AssetEntity>{};
      for (var i = 0; i < uniqueImages.length; i++) {
        final image = uniqueImages[i];
        scanPercent.value =
            25 + ((i + 1) / uniqueImages.length * 25).clamp(0, 25);
        if (i % 8 == 0) {
          scanStatus.value = 'Resolving: ${image.title ?? 'Image ${i + 1}'}';
          filesFound.value = i + 1;
          await Future.delayed(Duration.zero);
        }

        File? file;
        try {
          file = await image.originFile;
        } catch (_) {}
        file ??= await image.file;
        if (file == null) continue;
        final canon = _canonicalPath(file.path);
        if (!File(canon).existsSync()) continue;

        // Keep the first asset for this real file path.
        if (byPath.containsKey(canon)) continue;
        byPath[canon] = image;
        _imagePathById[image.id] = canon;
      }

      final pathEntries = byPath.entries.toList();
      if (pathEntries.isEmpty) {
        scanPercent.value = 100;
        duplicateImages.clear();
        return;
      }

      // Quick hash by size groups would help, but gallery set is smaller —
      // hash each unique path once.
      scanStatus.value = 'Comparing ${pathEntries.length} photos…';
      final quickGroups = <String, List<MapEntry<String, AssetEntity>>>{};
      for (var i = 0; i < pathEntries.length; i++) {
        final entry = pathEntries[i];
        scanPercent.value =
            50 + ((i + 1) / pathEntries.length * 30).clamp(0, 30);
        if (i % 6 == 0) {
          scanStatus.value =
              'Comparing: ${entry.value.title ?? 'Image ${i + 1}'}';
          await Future.delayed(Duration.zero);
        }
        final hash = await _quickHash(File(entry.key));
        if (hash.isEmpty) continue;
        quickGroups.putIfAbsent(hash, () => []).add(entry);
      }

      scanStatus.value = 'Verifying duplicates…';
      final confirmed = <List<AssetEntity>>[];
      final pending =
          quickGroups.values.where((g) => g.length > 1).toList();
      for (var gi = 0; gi < pending.length; gi++) {
        scanPercent.value = 80 + ((gi + 1) / pending.length * 20);
        final verified = await _verifyImageDuplicateGroup(pending[gi]);
        if (verified.length > 1) confirmed.add(verified);
        if (gi % 2 == 0) await Future.delayed(Duration.zero);
      }

      duplicateImages.assignAll(confirmed);
      scanPercent.value = 100;
      scanStatus.value = confirmed.isEmpty
          ? 'No true duplicates'
          : 'Found ${confirmed.length} groups';
    } catch (e) {
      Get.log('Error scanning duplicate images: $e');
      scanStatus.value = 'Scan failed';
    } finally {
      isScanningImages.value = false;
    }
  }

  Future<List<AssetEntity>> _verifyImageDuplicateGroup(
    List<MapEntry<String, AssetEntity>> entries,
  ) async {
    final byFull = <String, List<MapEntry<String, AssetEntity>>>{};
    for (final e in entries) {
      final f = File(e.key);
      if (!f.existsSync()) continue;
      final h = await _fullHash(f);
      if (h.isEmpty) continue;
      byFull.putIfAbsent(h, () => []).add(e);
    }

    List<AssetEntity> best = [];
    for (final g in byFull.values) {
      final uniquePaths = <String, AssetEntity>{};
      for (final e in g) {
        uniquePaths[e.key] = e.value;
      }
      if (uniquePaths.length > best.length) {
        best = uniquePaths.values.toList();
      }
    }
    return best.length > 1 ? best : [];
  }

  /// Fast candidate hash (size + sampled chunks).
  Future<String> _quickHash(File file) async {
    try {
      final size = await file.length();
      if (size <= 0) return '';
      if (size <= 1024 * 1024) {
        return '$size-${md5.convert(await file.readAsBytes())}';
      }
      final raf = await file.open();
      try {
        final head = await raf.read(128 * 1024);
        final midPos = (size ~/ 2) - (64 * 1024);
        await raf.setPosition(midPos.clamp(0, size - 1));
        final mid = await raf.read(128 * 1024);
        await raf.setPosition(size - 128 * 1024);
        final tail = await raf.read(128 * 1024);
        return '$size-${md5.convert([...head, ...mid, ...tail])}';
      } finally {
        await raf.close();
      }
    } catch (_) {
      return '';
    }
  }

  /// Full-file MD5 — used to confirm a candidate group is a real duplicate.
  Future<String> _fullHash(File file) async {
    try {
      final size = await file.length();
      if (size <= 0) return '';
      final digest = await md5.bind(file.openRead()).first;
      return '$size-$digest';
    } catch (_) {
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
      final deletedPath =
          _imagePathById[asset.id] ?? await _resolveAssetPath(asset);

      final List<String> result =
          await PhotoManager.editor.deleteWithIds([asset.id]);
      if (result.isEmpty) {
        throw Exception('Failed to delete asset');
      }

      _imagePathById.remove(asset.id);
      // If other listed "copies" were actually the same path, drop them too.
      await _pruneImageGroupsAfterDelete(
        deletedAssetId: asset.id,
        deletedPath: deletedPath,
      );
    } catch (e) {
      Get.log('Error deleting asset: $e');
      rethrow;
    }
  }

  Future<String?> _resolveAssetPath(AssetEntity asset) async {
    try {
      File? file;
      try {
        file = await asset.originFile;
      } catch (_) {}
      file ??= await asset.file;
      if (file == null) return null;
      return _canonicalPath(file.path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pruneImageGroupsAfterDelete({
    required String deletedAssetId,
    String? deletedPath,
  }) async {
    final next = <List<AssetEntity>>[];
    for (final group in duplicateImages) {
      final kept = <AssetEntity>[];
      final seenPaths = <String>{};
      for (final a in group) {
        if (a.id == deletedAssetId) continue;
        final path = _imagePathById[a.id] ?? await _resolveAssetPath(a);
        if (path == null) continue;
        if (deletedPath != null && path == deletedPath) continue;
        // Drop if the file is already gone from disk.
        if (!File(path).existsSync()) {
          _imagePathById.remove(a.id);
          continue;
        }
        if (!seenPaths.add(path)) continue;
        _imagePathById[a.id] = path;
        kept.add(a);
      }
      if (kept.length > 1) next.add(kept);
    }
    duplicateImages.assignAll(next);
  }

  Future<void> deleteFile(File file) async {
    try {
      final path = _canonicalPath(file.path);
      final f = File(path);
      if (f.existsSync()) {
        await f.delete();
      }
      _removeFileFromDuplicateGroups(path);
    } catch (e) {
      Get.log('Error deleting file: $e');
      rethrow;
    }
  }

  void _removeFileFromDuplicateGroups(String path) {
    final canon = _canonicalPath(path);
    final next = <List<File>>[];
    for (final group in duplicateFilesList) {
      final kept = <File>[];
      final seen = <String>{};
      for (final f in group) {
        final p = _canonicalPath(f.path);
        if (p == canon) continue;
        if (!File(p).existsSync()) continue;
        if (!seen.add(p)) continue;
        kept.add(File(p));
      }
      if (kept.length > 1) next.add(kept);
    }
    duplicateFilesList.assignAll(next);
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
