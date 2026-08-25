import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import '../../routes/app_routes.dart';
import 'storage_analyzer_controller.dart';

class StorageAnalyzerScreen extends GetView<StorageAnalyzerController> {
  const StorageAnalyzerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        leadingWidth: 56,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: Text('Storage Analyzer', style: openSansBold.copyWith(fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () => controller.refreshData(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Analyzing Storage...',
                    style: openSansMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
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
              ),
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
        style: openSansBold.copyWith(
          fontSize: 16,
          color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.85),
        ),
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
          borderRadius: BorderRadius.circular(AppUi.radiusLg),
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
        gradient: AppUi.brandHero,
        borderRadius: BorderRadius.circular(AppUi.radiusLg),
        boxShadow: AppUi.softGlow(AppUi.brandDeep),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.donut_large_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  'Storage Usage',
                  style: openSansBold.copyWith(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: CircularProgressIndicator(
                    value: usedPercent.clamp(0.0, 1.0),
                    strokeWidth: 14,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${(usedPercent * 100).toStringAsFixed(1)}%',
                      style: openSansExtraBold.copyWith(fontSize: 32, color: Colors.white),
                    ),
                    Text('Used', style: openSansRegular.copyWith(color: Colors.white70)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewItem('Total', '${totalGB.toInt()} GB', Icons.storage_rounded),
                _buildOverviewItem('Free', '${freeGB.toStringAsFixed(1)} GB', Icons.cloud_done_rounded),
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
                      Text('Quick Clean',
                          style: openSansSemiBold.copyWith(fontSize: 15)),
                      Text(
                        'Remove cache and temp files',
                        style: openSansRegular.copyWith(
                          fontSize: 12.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${controller.cacheSize.value.toStringAsFixed(1)} MB',
                  style: openSansBold.copyWith(
                      fontSize: 13, color: Colors.orange),
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
          // Navigate first — permission / scan happen on the destination screen.
          onTap: () => Get.toNamed(Routes.largeFiles),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.copy,
          color: Colors.purple,
          title: 'Duplicate Files',
          subtitle: Obx(() => Text('${controller.duplicateFilesList.length} duplicate groups')),
          onTap: () => Get.toNamed(Routes.duplicateFiles),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.images,
          color: Colors.green,
          title: 'Duplicate Images',
          subtitle: Obx(() => Text('${controller.duplicateImages.length} image groups')),
          onTap: () => Get.toNamed(Routes.duplicateImages),
        ),
        const SizedBox(height: 12),
        _buildToolTile(
          context,
          icon: FontAwesomeIcons.folderTree,
          color: Colors.amber,
          title: 'Storage Explorer',
          subtitle: const Text('Analyze folder sizes'),
          onTap: () => Get.toNamed(Routes.storageExplorer),
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

  Widget _buildToolTile(
    BuildContext context, {
    required FaIconData icon,
    required Color color,
    required String title,
    required Widget subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: FaIcon(icon, color: color, size: 20),
        ),
        title: Text(title, style: openSansSemiBold.copyWith(fontSize: 15)),
        subtitle: DefaultTextStyle(
          style: openSansRegular.copyWith(
            fontSize: 12.5,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
          ),
          child: subtitle,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
