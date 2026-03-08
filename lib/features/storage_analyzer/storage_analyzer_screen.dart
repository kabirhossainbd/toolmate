import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'storage_analyzer_controller.dart';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'duplicate_images_screen.dart';
import 'large_files_screen.dart';
import 'duplicate_files_screen.dart';
import 'storage_explorer_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageAnalyzerScreen extends GetView<StorageAnalyzerController> {
  const StorageAnalyzerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Analyzer', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => controller.refreshData(),
          ).animate().rotate(),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Analyzing Storage...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStorageOverview(context),
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Optimization Tools'),
                  const SizedBox(height: 12),
                  _buildToolsList(context),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStorageOverview(BuildContext context) {
    final space = controller.storageSpace.value;
    if (space == null) {
      return Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('Storage info unavailable')),
      );
    }

    double totalGB = controller.getStandardTotal(space.total).toDouble();
    double freeGB = space.free / (1024 * 1024 * 1024);
    double usedGB = totalGB - freeGB;
    double usedPercent = usedGB / totalGB;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Storage Usage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: CircularProgressIndicator(
                    value: usedPercent,
                    strokeWidth: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                    strokeCap: StrokeCap.round,
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                Column(
                  children: [
                    Text(
                      '${(usedPercent * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Text('Used', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewItem('Total', '${totalGB.toInt()} GB', Icons.storage),
                _buildOverviewItem('Free', '${freeGB.toStringAsFixed(1)} GB', Icons.cloud_done),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _confirmCleanCache(),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Clean', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Remove cache and temp files', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                Text(
                  '${controller.cacheSize.value.toStringAsFixed(1)} MB',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmCleanCache() {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Get.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.cleaning_services_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Clean Cache', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete temporary files? This will free up approximately ${controller.cacheSize.value.toStringAsFixed(2)} MB.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        controller.cleanCache();
                        Get.back();
                        Get.snackbar(
                          'Cache Cleaned',
                          'System cache cleared successfully!',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green,
                          colorText: Colors.white,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Clean Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolsList(BuildContext context) {
    return Column(
      children: [
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.fileLines,
          color: Colors.blue,
          title: 'Large Files',
          subtitle: Obx(() => Text('${controller.largeFiles.length} files > 10MB')),
          onTap: () => _handleToolNavigation(
            context,
            permission: Permission.manageExternalStorage,
            title: 'Storage Access Required',
            message: 'To find large files, we need permission to scan your storage.',
            onConfirm: () => Get.to(() => const LargeFilesScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.copy,
          color: Colors.purple,
          title: 'Duplicate Files',
          subtitle: Obx(() => Text('${controller.duplicateFilesList.length} duplicate groups')),
          onTap: () => _handleToolNavigation(
            context,
            permission: Permission.manageExternalStorage,
            title: 'Storage Access Required',
            message: 'To find duplicate files, we need permission to scan your storage.',
            onConfirm: () => Get.to(() => const DuplicateFilesScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.images,
          color: Colors.green,
          title: 'Duplicate Images',
          subtitle: Obx(() => Text('${controller.duplicateImages.length} image groups')),
          onTap: () => _handleToolNavigation(
            context,
            permission: Permission.photos,
            title: 'Gallery Access Required',
            message: 'To find duplicate images, we need permission to access your gallery.',
            onConfirm: () => Get.to(() => const DuplicateImagesScreen()),
            isGallery: true,
          ),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.folderTree,
          color: Colors.amber,
          title: 'Storage Explorer',
          subtitle: const Text('Analyze folder sizes'),
          onTap: () => _handleToolNavigation(
            context,
            permission: Permission.manageExternalStorage,
            title: 'Storage Access Required',
            message: 'To analyze folders, we need permission to scan your storage.',
            onConfirm: () => Get.to(() => const StorageExplorerScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.cubes,
          color: Colors.blueGrey,
          title: 'App Data',
          subtitle: Obx(() => Text('${controller.appSize.value.toStringAsFixed(1)} MB used')),
          onTap: () {},
        ),
      ],
    );
  }

  void _handleToolNavigation(
    BuildContext context, {
    required dynamic permission,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isGallery = false,
  }) async {
    bool isGranted = false;
    if (isGallery) {
      final status = await PhotoManager.requestPermissionExtend();
      isGranted = status.isAuth;
    } else {
      isGranted = await (permission as Permission).isGranted;
    }

    if (isGranted) {
      onConfirm();
      return;
    }

    Get.dialog(
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
                  color: (isGallery ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGallery ? Icons.photo_library_rounded : Icons.folder_shared_rounded,
                  color: isGallery ? Colors.green : Colors.blue,
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
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Not Now'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        if (isGallery) {
                          final status = await PhotoManager.requestPermissionExtend();
                          if (status.isAuth) onConfirm();
                        } else {
                          final status = await (permission as Permission).request();
                          if (status.isGranted) onConfirm();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isGallery ? Colors.green : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }

  Widget _buildToolTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required Widget subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildBottomSheetContainer(BuildContext context, {required String title, required Widget child}) {
    return Container(
      height: Get.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Get.back()),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildFileItem({required String name, required String size, required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Get.theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_rounded, color: Colors.blue),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
        subtitle: Text(size, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }

  void _confirmDeleteFile(File file, VoidCallback onDeleted) {
    Get.defaultDialog(
      title: 'Delete File',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      middleText: 'This action cannot be undone. Are you sure?',
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        try {
          await controller.deleteFile(file);
          onDeleted();
          Get.back();
          Get.snackbar('Deleted', 'File removed successfully', snackPosition: SnackPosition.BOTTOM);
        } catch (e) {
          Get.back();
          Get.snackbar('Error', 'Could not delete file', backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }
}
