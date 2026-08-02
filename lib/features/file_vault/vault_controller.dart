import 'dart:io';

import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultController extends GetxController {
  static const _boxName = 'app_settings';
  static const _pinKey = 'vault_pin';

  final ImagePicker _picker = ImagePicker();

  late Box _settings;

  final RxBool isUnlocked = false.obs;
  final RxBool hasPin = false.obs;
  final RxBool isLoading = false.obs;
  final RxList<File> files = <File>[].obs;
  final RxString errorMessage = ''.obs;

  Directory? _vaultDir;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    isLoading.value = true;
    try {
      _settings = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      hasPin.value = (_settings.get(_pinKey) as String?)?.isNotEmpty == true;

      final docs = await getApplicationDocumentsDirectory();
      _vaultDir = Directory(p.join(docs.path, 'vault'));
      if (!await _vaultDir!.exists()) {
        await _vaultDir!.create(recursive: true);
      }
    } catch (e) {
      errorMessage.value = 'Failed to initialize vault: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> setPin(String pin) async {
    final trimmed = pin.trim();
    if (trimmed.length < 4) {
      errorMessage.value = 'PIN must be at least 4 digits';
      return false;
    }
    await _settings.put(_pinKey, trimmed);
    hasPin.value = true;
    isUnlocked.value = true;
    errorMessage.value = '';
    await loadFiles();
    return true;
  }

  Future<bool> unlock(String pin) async {
    final stored = _settings.get(_pinKey) as String?;
    if (stored == null || stored.isEmpty) {
      errorMessage.value = 'No PIN set';
      return false;
    }
    if (pin.trim() != stored) {
      errorMessage.value = 'Incorrect PIN';
      return false;
    }
    isUnlocked.value = true;
    errorMessage.value = '';
    await loadFiles();
    return true;
  }

  void lock() {
    isUnlocked.value = false;
  }

  Future<void> loadFiles() async {
    if (_vaultDir == null) return;
    try {
      if (!await _vaultDir!.exists()) {
        await _vaultDir!.create(recursive: true);
      }
      final listed = _vaultDir!
          .listSync()
          .whereType<File>()
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      files.assignAll(listed);
    } catch (e) {
      errorMessage.value = 'Failed to list vault files: $e';
    }
  }

  Future<void> importFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      await importFromPath(picked.path);
    } catch (e) {
      errorMessage.value = 'Import failed: $e';
      Get.snackbar('Vault', 'Could not import image');
    }
  }

  Future<void> importFromCamera() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked == null) return;
      await importFromPath(picked.path);
    } catch (e) {
      errorMessage.value = 'Camera import failed: $e';
      Get.snackbar('Vault', 'Could not capture image');
    }
  }

  Future<void> importFromPath(String sourcePath) async {
    if (_vaultDir == null) return;
    final source = File(sourcePath);
    if (!await source.exists()) {
      Get.snackbar('Vault', 'File not found');
      return;
    }
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
    final dest = File(p.join(_vaultDir!.path, name));
    await source.copy(dest.path);
    await loadFiles();
    Get.snackbar('Vault', 'File imported');
  }

  Future<void> deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await loadFiles();
    } catch (e) {
      Get.snackbar('Vault', 'Delete failed: $e');
    }
  }

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
