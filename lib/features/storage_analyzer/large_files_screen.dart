import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'storage_analyzer_controller.dart';

class LargeFilesScreen extends GetView<StorageAnalyzerController> {
  const LargeFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Start scan when screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.largeFiles.isEmpty && !controller.isScanningLargeFiles.value) {
        controller.scanLargeFiles();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Large Files', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isScanningLargeFiles.value) {
            return _buildLoader();
          }

          if (controller.largeFiles.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: controller.largeFiles.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final file = controller.largeFiles[index];
              return _buildFileItem(context, file);
            },
          );
        }),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Obx(() => CircularProgressIndicator(
                  value: controller.totalToScan.value > 0 
                      ? controller.scanProgress.value / controller.totalToScan.value 
                      : null,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                  color: Colors.blue,
                )),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() => Text(
                    controller.totalToScan.value > 0 
                        ? '${((controller.scanProgress.value / controller.totalToScan.value) * 100).toInt()}%'
                        : '${controller.filesFound.value}',
                    style: TextStyle(
                      fontSize: controller.totalToScan.value > 0 ? 24 : 32, 
                      fontWeight: FontWeight.bold
                    ),
                  )),
                  Obx(() => Text(
                    controller.totalToScan.value > 0
                        ? '${controller.scanProgress.value}/${controller.totalToScan.value}'
                        : 'Files found',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Scanning Large Files...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Obx(() => Text(
              controller.scanStatus.value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No large files found (>10MB)', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, File file) {
    String fileName = file.path.split('/').last;
    String size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insert_drive_file_rounded, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$size MB',
                        style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getShortPath(file.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),


          IconButton(
            onPressed: () => _confirmDeleteFile(file),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(File file) {
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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Delete Large File?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete "${file.path.split('/').last}"?',
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
                      onPressed: () async {
                        try {
                          Get.back();
                          await controller.deleteFile(file);
                          controller.largeFiles.remove(file);
                          Get.snackbar('Deleted', 'File removed successfully',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: Colors.green,
                            colorText: Colors.white);
                        } catch (e) {
                          Get.back();
                          Get.snackbar('Error', 'Could not delete file',
                            backgroundColor: Colors.red, colorText: Colors.white);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Delete Now'),
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

  String _getShortPath(String path) {
    try {
      List<String> parts = path.split('/');
      if (parts.length > 1) {
        // Show the parent folder name
        return 'in ${parts[parts.length - 2]}';
      }
    } catch (_) {}
    return path;
  }
}
