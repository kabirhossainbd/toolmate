import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'storage_analyzer_controller.dart';
import 'dart:io';

class StorageAnalyzerScreen extends GetView<StorageAnalyzerController> {
  const StorageAnalyzerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Analyzer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshData(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
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
                const SizedBox(height: 16),
                _buildActionButtons(context),
                const SizedBox(height: 16),
                _buildToolsList(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStorageOverview(BuildContext context) {
    final space = controller.storageSpace.value;
    if (space == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: Text('Storage info unavailable')),
        ),
      );
    }

    // Convert sizes to GB for display
    double totalGB = space.total / (1024 * 1024 * 1024);
    double freeGB = space.free / (1024 * 1024 * 1024);
    double usedGB = space.used / (1024 * 1024 * 1024);
    double usedPercent = space.used / space.total;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Storage Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 150,
                  width: 150,
                  child: CircularProgressIndicator(
                    value: usedPercent,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${(usedPercent * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text('Used'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Total', '${totalGB.toStringAsFixed(1)} GB', Colors.black),
                _buildLegendItem('Used', '${usedGB.toStringAsFixed(1)} GB', Theme.of(context).colorScheme.primary),
                _buildLegendItem('Free', '${freeGB.toStringAsFixed(1)} GB', Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Trigger cache clean
              Get.defaultDialog(
                title: 'Clean Cache',
                middleText: 'Are you sure you want to clean app cache? (${controller.cacheSize.value.toStringAsFixed(2)} MB)',
                textConfirm: 'Clean',
                textCancel: 'Cancel',
                confirmTextColor: Colors.white,
                onConfirm: () {
                  controller.cleanCache();
                  Get.back();
                  Get.snackbar('Success', 'Cache cleaned successfully');
                },
              );
            },
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Clean Cache'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsList(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_special, color: Colors.amber),
            title: const Text('Large Files'),
            subtitle: Obx(() => Text('${controller.largeFiles.length} files found > 10MB')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (controller.largeFiles.isEmpty) {
                controller.scanLargeFiles();
              }
              _showLargeFilesDialog(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.image, color: Colors.green),
            title: const Text('Duplicate Images'),
            subtitle: Obx(() => Text('${controller.duplicateImages.length} duplicate groups found')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (controller.duplicateImages.isEmpty) {
                controller.findDuplicateImages();
              } else {
                Get.snackbar('Feature', 'Duplicate image viewer UI coming soon');
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.apps, color: Colors.blue),
            title: const Text('App Size'),
            subtitle: Obx(() => Text('${controller.appSize.value.toStringAsFixed(2)} MB')),
          ),
        ],
      ),
    );
  }

  void _showLargeFilesDialog(BuildContext context) {
    Get.bottomSheet(
      Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Large Files (>10MB)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.largeFiles.isEmpty) {
                  return const Center(child: Text('No large files found.'));
                }
                return ListView.builder(
                  itemCount: controller.largeFiles.length,
                  itemBuilder: (context, index) {
                    File file = controller.largeFiles[index];
                    String name = file.path.split('/').last;
                    double sizeMB = file.lengthSync() / (1024 * 1024);
                    return ListTile(
                      leading: const Icon(Icons.insert_drive_file),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${sizeMB.toStringAsFixed(2)} MB'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Simple delete confirmation
                          Get.defaultDialog(
                            title: 'Delete File',
                            middleText: 'Are you sure you want to delete this file?',
                            textConfirm: 'Delete',
                            textCancel: 'Cancel',
                            confirmTextColor: Colors.white,
                            onConfirm: () {
                              try {
                                file.deleteSync();
                                controller.largeFiles.removeAt(index);
                                Get.back();
                              } catch (e) {
                                Get.back();
                                Get.snackbar('Error', 'Could not delete file');
                              }
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
