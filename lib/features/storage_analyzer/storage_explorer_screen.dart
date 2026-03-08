import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'storage_analyzer_controller.dart';
import 'dart:io';

class StorageExplorerScreen extends GetView<StorageAnalyzerController> {
  final String path;
  
  const StorageExplorerScreen({
    super.key, 
    this.path = '/storage/emulated/0',
  });

  @override
  Widget build(BuildContext context) {
    // Start analysis for the specific path
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.listFolderContent(path);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Obx(() {
                if (controller.isScanningFolders.value && controller.currentFolderContent.isEmpty) {
                  return _buildLoader();
                }

                if (controller.currentFolderContent.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  itemCount: controller.currentFolderContent.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final item = controller.currentFolderContent[index];
                    return _buildFileItem(context, item);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        path,
        style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing...', style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No items found'),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, FileSystemEntityInfo item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildIcon(item),
      title: Text(
        item.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.isFolder 
            ? '${controller.formatSize(item.size)} (${item.itemCount} items)'
            : controller.formatSize(item.size),
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
      trailing: item.isFolder 
          ? null 
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              onPressed: () => _showDeleteConfirmation(context, item),
            ),
      onTap: () {
        if (item.isFolder) {
          Get.to(
            () => StorageExplorerScreen(path: item.path), 
            preventDuplicates: false,
          )?.then((_) {
            // Re-list current folder when returning from sub-folder
            controller.listFolderContent(path);
          });
        }
      },
    );
  }

  Widget _buildIcon(FileSystemEntityInfo item) {
    if (item.isFolder) {
      return const Icon(Icons.folder_rounded, color: Colors.amber, size: 40);
    }
    
    final ext = item.extension;
    if (ext != null && ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.path),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          cacheWidth: 120, // Optimization for thumbnails
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.image_rounded, 
            color: Colors.blue, 
            size: 40
          ),
        ),
      );
    }
    
    IconData iconData = Icons.insert_drive_file_rounded;
    Color color = Colors.grey;

    if (ext != null) {
      if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) {
        iconData = Icons.videocam_rounded;
        color = Colors.purple;
      } else if (['mp3', 'wav', 'm4a', 'flac'].contains(ext)) {
        iconData = Icons.audiotrack_rounded;
        color = Colors.orange;
      } else if (['pdf', 'doc', 'docx', 'txt', 'epub'].contains(ext)) {
        iconData = Icons.description_rounded;
        color = Colors.red;
      } else if (ext == 'apk') {
        iconData = Icons.android_rounded;
        color = Colors.green;
      } else if (ext == 'zip' || ext == 'rar') {
        iconData = Icons.archive_rounded;
        color = Colors.brown;
      }
    }

    return Icon(iconData, color: color, size: 40);
  }

  void _showDeleteConfirmation(BuildContext context, FileSystemEntityInfo item) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete ${item.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _performDelete(item);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(FileSystemEntityInfo item) async {
    try {
      await controller.deleteFileSystemEntity(item.path);
      Get.snackbar(
        'Success',
        'Item deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not delete item: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
