import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'storage_analyzer_controller.dart';

class DuplicateFilesScreen extends GetView<StorageAnalyzerController> {
  const DuplicateFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Start scan when screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.duplicateFilesList.isEmpty && !controller.isScanningDuplicates.value) {
        controller.findAllDuplicateFiles();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Files', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isScanningDuplicates.value) {
            return _buildLoader();
          }

          if (controller.duplicateFilesList.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: controller.duplicateFilesList.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final group = controller.duplicateFilesList[index];
              return _buildFileDuplicateGroup(context, group, index);
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
                  color: Colors.orange,
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
          const Text('Analyzing Duplicates...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Obx(() => Text(
              controller.scanStatus.value,
              textAlign: TextAlign.center,
              maxLines: 2,
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
          Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green[200]),
          const SizedBox(height: 16),
          Text('No duplicate files found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFileDuplicateGroup(BuildContext context, List<File> group, int groupIndex) {
    String firstFileName = group[0].path.split('/').last;
    String size = (group[0].lengthSync() / (1024 * 1024)).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstFileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),

                      Text(
                        '$size MB each • ${group.length} copies',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: group.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
            itemBuilder: (context, index) {
              File file = group[index];
              String fullPath = file.path;
              List<String> pathParts = fullPath.split('/');
              String displayPath = pathParts.length > 2 
                ? '.../${pathParts[pathParts.length - 2]}/${pathParts.last}'
                : fullPath;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: index == 0 
                        ? const Tooltip(message: 'Original', child: Icon(Icons.star_rounded, color: Colors.amber, size: 20))
                        : const Icon(Icons.insert_drive_file_outlined, size: 18, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayPath,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDeleteFile(file, () {
                        group.removeAt(index);
                        if (group.length < 2) {
                          controller.duplicateFilesList.removeAt(groupIndex);
                        }
                        controller.duplicateFilesList.refresh();
                      }),
                    ),
                  ],
                ),
              );
            },
          ),

        ],
      ),
    );
  }

  void _confirmDeleteFile(File file, VoidCallback onDeleted) {
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
              const Icon(Icons.delete_forever_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Delete Duplicate?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'This exact copy will be permanently removed from your storage.',
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
                          await controller.deleteFile(file);
                          onDeleted();
                          Get.back();
                          Get.snackbar('Deleted', 'File removed successfully',
                            snackPosition: SnackPosition.BOTTOM,
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
}
