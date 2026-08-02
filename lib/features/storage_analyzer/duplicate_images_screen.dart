import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'storage_analyzer_controller.dart';

class DuplicateImagesScreen extends GetView<StorageAnalyzerController> {
  const DuplicateImagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Start scan when screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.duplicateImages.isEmpty && !controller.isScanningImages.value) {
        controller.findDuplicateImages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Images', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isScanningImages.value) {
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
                      child: CircularProgressIndicator(
                        value: controller.totalToScan.value > 0 
                            ? controller.scanProgress.value / controller.totalToScan.value 
                            : null,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        color: Colors.green,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          controller.totalToScan.value > 0 
                              ? '${((controller.scanProgress.value / controller.totalToScan.value) * 100).toInt()}%'
                              : '0%',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${controller.scanProgress.value}/${controller.totalToScan.value}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Analyzing Images...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('Comparing files for duplicates', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        if (controller.duplicateImages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No duplicate images found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const ClampingScrollPhysics(),
          cacheExtent: 200,
          addAutomaticKeepAlives: false,
          itemCount: controller.duplicateImages.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final group = controller.duplicateImages[index];
            return _buildImageDuplicateGroup(context, group, index);
          },
        );
      }),
    );
  }

  Widget _buildImageDuplicateGroup(BuildContext context, List<AssetEntity> group, int groupIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
        ),
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
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.collections_rounded, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Group ${groupIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${group.length} duplicates',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: group.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final asset = group[index];
                return SizedBox(
                  width: 88,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AssetEntityImage(
                          asset,
                          isOriginal: false,
                          thumbnailSize: const ThumbnailSize(120, 120),
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _confirmDeleteAsset(asset, () {
                              group.removeAt(index);
                              if (group.length < 2) {
                                controller.duplicateImages.removeAt(groupIndex);
                              }
                              controller.duplicateImages.refresh();
                            }),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.redAccent,
                              child: Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAsset(AssetEntity asset, VoidCallback onDeleted) {
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
              const Text('Delete Image?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'This duplicate image will be permanently removed from your device gallery.',
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
                          await controller.deleteAsset(asset);
                          onDeleted();
                          Get.back();
                          Get.snackbar('Deleted', 'Image removed successfully',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: Colors.green,
                            colorText: Colors.white);
                        } catch (e) {
                          Get.back();
                          Get.snackbar('Error', 'Could not delete image',
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
