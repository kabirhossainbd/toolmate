import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:storage_space/storage_space.dart';

/// Isolate entry — sync filesystem walk so UI isolate stays free.
List<Map<String, Object>> _scanLargeFilesIsolate(Map<String, Object> args) {
  final rootPath = args['root']! as String;
  final minBytes = args['minBytes']! as int;
  final maxResults = args['maxResults']! as int;

  final found = <MapEntry<String, int>>[];

  void walk(Directory dir) {
    try {
      for (final entity in dir.listSync(recursive: false, followLinks: false)) {
        if (entity is File) {
          try {
            final len = entity.lengthSync();
            if (len > minBytes) found.add(MapEntry(entity.path, len));
          } catch (_) {}
        } else if (entity is Directory) {
          final path = entity.path.toLowerCase();
          if (!path.contains('/.') &&
              !path.contains('/android') &&
              !path.contains('/obb')) {
            walk(entity);
          }
        }
      }
    } catch (_) {}
  }

  walk(Directory(rootPath));
  found.sort((a, b) => b.value.compareTo(a.value));
  return found
      .take(maxResults)
      .map((e) => <String, Object>{'path': e.key, 'size': e.value})
      .toList(growable: false);
}

class StorageAnalyzerController extends GetxController {
  final Rx<StorageSpace?> storageSpace = Rx<StorageSpace?>(null);
  final RxList<File> largeFiles = <File>[].obs;
  /// Cached sizes from isolate so list tiles never call lengthSync.
  final Map<String, int> largeFileSizes = {};
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

  int _largeScanGen = 0;
  int _dupFilesScanGen = 0;
  int _dupImagesScanGen = 0;

  /// Real shared-storage path for each gallery asset id (never app-cache paths).
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

  /// App-private / cache paths from photo_manager are NOT unique disk copies.
  /// Using them as identity caused false duplicates (delete one → both gone).
  bool _isAppPrivatePath(String path) {
    final p = path.toLowerCase();
    if (p.contains('/cache/')) return true;
    if (p.contains('/code_cache/')) return true;
    if (p.contains('/app_flutter/')) return true;
    if (p.contains('/files/photos/')) return true;
    if (RegExp(r'/data/(data|user/\d+)/').hasMatch(p)) return true;
    return false;
  }

  /// Soft identity from MediaStore metadata (same photo listed twice).
  String _assetSoftKey(AssetEntity a) {
    final rel = (a.relativePath ?? '').trim();
    final title = (a.title ?? '').trim();
    if (title.isNotEmpty) return '$rel|$title';
    // No display name — never collapse unknowns together.
    return 'id:${a.id}';
  }

  /// Prefer the real file under shared storage (DCIM/Download/…) over a
  /// temporary cache copy created by photo_manager.
  Future<String?> _resolveRealGalleryPath(AssetEntity asset) async {
    final title = (asset.title ?? '').trim();
    final rel = (asset.relativePath ?? '').trim();
    if (title.isNotEmpty && rel.isNotEmpty) {
      final relNorm = rel.endsWith('/') ? rel : '$rel/';
      for (final root in const [
        '/storage/emulated/0',
        '/sdcard',
      ]) {
        final candidate = _canonicalPath('$root/$relNorm$title');
        if (!_isAppPrivatePath(candidate) && File(candidate).existsSync()) {
          return candidate;
        }
      }
    }

    File? file;
    try {
      file = await asset.originFile;
    } catch (_) {}
    file ??= await asset.file;
    if (file == null) return null;

    final path = _canonicalPath(file.path);
    if (_isAppPrivatePath(path)) return null;
    if (!File(path).existsSync()) return null;
    return path;
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
    final gen = ++_largeScanGen;
    isScanningLargeFiles.value = true;
    largeFiles.clear();
    largeFileSizes.clear();
    _resetScanUi(status: 'Scanning storage…');
    scanIndeterminate.value = true;

    try {
      final root = await _getPrimaryStorage();
      if (gen != _largeScanGen) return;
      if (!root.existsSync()) {
        scanStatus.value = 'Storage not available';
        return;
      }

      scanStatus.value = 'Walking storage…';
      final rows = await compute(
        _scanLargeFilesIsolate,
        <String, Object>{
          'root': root.path,
          'minBytes': 10 * 1024 * 1024,
          'maxResults': 50,
        },
      );
      if (gen != _largeScanGen) return;

      for (final row in rows) {
        final path = row['path']! as String;
        largeFileSizes[path] = row['size']! as int;
      }
      largeFiles.assignAll(rows.map((row) => File(row['path']! as String)));
      filesFound.value = rows.length;
      scanPercent.value = 100;
      scanIndeterminate.value = false;
      scanStatus.value = 'Done';
    } catch (e) {
      if (gen != _largeScanGen) return;
      Get.log('Large Scan - Error: $e');
      scanStatus.value = 'Scan failed';
    } finally {
      if (gen == _largeScanGen) {
        isScanningLargeFiles.value = false;
      }
    }
  }

  void cancelLargeFilesScan() {
    _largeScanGen++;
    if (isScanningLargeFiles.value) {
      isScanningLargeFiles.value = false;
      scanStatus.value = 'Cancelled';
    }
  }

  void cancelDuplicateFilesScan() {
    _dupFilesScanGen++;
    if (isScanningDuplicates.value) {
      isScanningDuplicates.value = false;
      scanStatus.value = 'Cancelled';
    }
  }

  void cancelDuplicateImagesScan() {
    _dupImagesScanGen++;
    if (isScanningImages.value) {
      isScanningImages.value = false;
      scanStatus.value = 'Cancelled';
    }
  }

  Future<void> findAllDuplicateFiles() async {
    final gen = ++_dupFilesScanGen;
    isScanningDuplicates.value = true;
    duplicateFilesList.clear();
    _resetScanUi(status: 'Scanning storage…');

    try {
      final root = await _getPrimaryStorage();
      if (gen != _dupFilesScanGen) return;
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
        if (scanned % 40 != 0) return;
        if (gen != _dupFilesScanGen) return;
        filesFound.value = scanned;
        scanPercent.value =
            (3 + (scanned / (scanned + 500)) * 40).clamp(3.0, 43.0);
        scanStatus.value = 'Indexed $scanned files…';
        await Future<void>.delayed(Duration.zero);
      });

      if (gen != _dupFilesScanGen) return;
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
        if (i % 12 == 0) {
          final done = i + 1;
          scanStatus.value =
              'Comparing files… $done/${candidates.length}';
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
      if (gen == _dupFilesScanGen) {
        isScanningDuplicates.value = false;
      }
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
    final gen = ++_dupImagesScanGen;
    isScanningImages.value = true;
    duplicateImages.clear();
    _imagePathById.clear();
    _resetScanUi(status: 'Accessing gallery…');

    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (gen != _dupImagesScanGen) return;
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
            count == 0 ? 8 : (allImages.length / count * 20).clamp(0, 20);
        scanStatus.value = 'Loading gallery… ${allImages.length}/$count';
        await Future.delayed(Duration.zero);
      }

      // Unique MediaStore id.
      final byId = <String, AssetEntity>{};
      for (final img in allImages) {
        byId.putIfAbsent(img.id, () => img);
      }
      final uniqueImages = byId.values.toList();

      // Resolve each asset to a REAL shared-storage path.
      // Same soft-key / same path → one entry (not a duplicate group).
      final byPath = <String, AssetEntity>{};
      final seenSoft = <String>{};
      var resolved = 0;
      for (var i = 0; i < uniqueImages.length; i++) {
        final image = uniqueImages[i];
        scanPercent.value =
            20 + ((i + 1) / uniqueImages.length * 25).clamp(0, 25);
        if (i % 12 == 0) {
          scanStatus.value =
              'Reading photos… ${i + 1}/${uniqueImages.length}';
          filesFound.value = i + 1;
          await Future.delayed(Duration.zero);
        }

        final soft = _assetSoftKey(image);
        if (!seenSoft.add(soft)) continue;

        final path = await _resolveRealGalleryPath(image);
        if (path == null) continue;
        if (byPath.containsKey(path)) continue;

        byPath[path] = image;
        _imagePathById[image.id] = path;
        resolved++;
      }

      if (byPath.length < 2) {
        scanPercent.value = 100;
        duplicateImages.clear();
        scanStatus.value = resolved == 0
            ? 'Could not read photo files'
            : 'No duplicate images';
        return;
      }

      // Same size first — identical files always share length.
      scanStatus.value = 'Grouping by size…';
      final sizeGroups = <int, List<MapEntry<String, AssetEntity>>>{};
      for (final entry in byPath.entries) {
        try {
          final len = await File(entry.key).length();
          if (len <= 0) continue;
          sizeGroups.putIfAbsent(len, () => []).add(entry);
        } catch (_) {}
      }
      final sizeCandidates =
          sizeGroups.values.where((g) => g.length > 1).toList();
      scanPercent.value = 50;

      if (sizeCandidates.isEmpty) {
        scanPercent.value = 100;
        duplicateImages.clear();
        scanStatus.value = 'No duplicate images';
        return;
      }

      scanStatus.value = 'Comparing photos…';
      final quickGroups = <String, List<MapEntry<String, AssetEntity>>>{};
      var compared = 0;
      final totalCompare =
          sizeCandidates.fold<int>(0, (s, g) => s + g.length);
      for (final group in sizeCandidates) {
        for (final entry in group) {
          compared++;
          scanPercent.value =
              50 + ((compared / totalCompare) * 30).clamp(0, 30);
          if (compared % 12 == 0) {
            scanStatus.value = 'Comparing photos… $compared/$totalCompare';
            await Future.delayed(Duration.zero);
          }
          final hash = await _quickHash(File(entry.key));
          if (hash.isEmpty) continue;
          quickGroups.putIfAbsent(hash, () => []).add(entry);
        }
      }

      scanStatus.value = 'Verifying duplicates…';
      final confirmed = <List<AssetEntity>>[];
      final pending =
          quickGroups.values.where((g) => g.length > 1).toList();
      for (var gi = 0; gi < pending.length; gi++) {
        scanPercent.value = pending.isEmpty
            ? 90
            : 80 + ((gi + 1) / pending.length * 20);
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
      if (gen == _dupImagesScanGen) {
        isScanningImages.value = false;
      }
    }
  }

  Future<List<AssetEntity>> _verifyImageDuplicateGroup(
    List<MapEntry<String, AssetEntity>> entries,
  ) async {
    // Must be different real paths (never aliases of one file).
    final byPath = <String, AssetEntity>{};
    for (final e in entries) {
      final path = _canonicalPath(e.key);
      if (_isAppPrivatePath(path)) continue;
      if (!File(path).existsSync()) continue;
      byPath.putIfAbsent(path, () => e.value);
    }
    if (byPath.length < 2) return [];

    final byFull = <String, List<MapEntry<String, AssetEntity>>>{};
    for (final e in byPath.entries) {
      final h = await _fullHash(File(e.key));
      if (h.isEmpty) continue;
      byFull.putIfAbsent(h, () => []).add(MapEntry(e.key, e.value));
    }

    List<AssetEntity> best = [];
    for (final g in byFull.values) {
      final uniquePaths = <String, AssetEntity>{};
      final softKeys = <String>{};
      for (final e in g) {
        final soft = _assetSoftKey(e.value);
        if (!softKeys.add(soft)) continue;
        uniquePaths[e.key] = e.value;
        _imagePathById[e.value.id] = e.key;
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
          _imagePathById[asset.id] ?? await _resolveRealGalleryPath(asset);

      // Gallery delete must go through MediaStore only — never File.delete().
      // File.delete on a shared path is what made "both copies" vanish.
      final List<String> result =
          await PhotoManager.editor.deleteWithIds([asset.id]);
      if (result.isEmpty) {
        throw Exception('Failed to delete asset');
      }

      _imagePathById.remove(asset.id);
      await _pruneImageGroupsAfterDelete(
        deletedAssetId: asset.id,
        deletedPath: deletedPath,
      );
    } catch (e) {
      Get.log('Error deleting asset: $e');
      rethrow;
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
      final seenSoft = <String>{};

      for (final a in group) {
        if (a.id == deletedAssetId) continue;

        // Re-check the asset still exists in MediaStore.
        final still = await AssetEntity.fromId(a.id);
        if (still == null) {
          _imagePathById.remove(a.id);
          continue;
        }

        final path =
            _imagePathById[a.id] ?? await _resolveRealGalleryPath(still);
        if (path == null) {
          _imagePathById.remove(a.id);
          continue;
        }

        // Same physical file as the one we deleted → drop from UI only.
        if (deletedPath != null &&
            _canonicalPath(path) == _canonicalPath(deletedPath)) {
          _imagePathById.remove(a.id);
          continue;
        }

        if (!File(path).existsSync()) {
          _imagePathById.remove(a.id);
          continue;
        }

        final soft = _assetSoftKey(still);
        if (!seenSoft.add(soft)) continue;
        if (!seenPaths.add(_canonicalPath(path))) continue;

        _imagePathById[still.id] = path;
        kept.add(still);
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

  final RxList<FileSystemEntityInfo> currentFolderContent =
      <FileSystemEntityInfo>[].obs;
  final RxString currentPath = '/storage/emulated/0'.obs;

  /// Bumps on every list request so stale async work is ignored.
  int _folderListGen = 0;

  /// Fast shallow listing only — no recursive size walks (those froze navigation).
  Future<void> listFolderContent(String path) async {
    final gen = ++_folderListGen;
    currentPath.value = path;
    isScanningFolders.value = true;

    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        if (gen == _folderListGen) currentFolderContent.clear();
        return;
      }

      final items = <FileSystemEntityInfo>[];
      await for (final entity
          in dir.list(recursive: false, followLinks: false)) {
        if (gen != _folderListGen) return;

        final name = entity.path.split('/').last;
        if (name.startsWith('.')) continue;

        if (entity is Directory) {
          items.add(FileSystemEntityInfo(
            name: name,
            path: entity.path,
            isFolder: true,
            size: 0,
            itemCount: 0,
          ));
        } else if (entity is File) {
          var size = 0;
          try {
            size = await entity.length();
          } catch (_) {}
          items.add(FileSystemEntityInfo(
            name: name,
            path: entity.path,
            isFolder: false,
            size: size,
            extension: name.contains('.')
                ? name.split('.').last.toLowerCase()
                : null,
          ));
        }

        // Keep UI responsive while listing large folders.
        if (items.length % 40 == 0) await Future.delayed(Duration.zero);
      }

      if (gen != _folderListGen) return;

      items.sort((a, b) {
        if (a.isFolder && !b.isFolder) return -1;
        if (!a.isFolder && b.isFolder) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      currentFolderContent.assignAll(items);
    } catch (e) {
      Get.log('Error listing folder content: $e');
      if (gen == _folderListGen) currentFolderContent.clear();
    } finally {
      if (gen == _folderListGen) isScanningFolders.value = false;
    }
  }

  Future<void> deleteFileSystemEntity(String path) async {
    try {
      final entity =
          FileSystemEntity.isFileSync(path) ? File(path) : Directory(path);
      if (await entity.exists()) {
        await entity.delete(recursive: true);
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
