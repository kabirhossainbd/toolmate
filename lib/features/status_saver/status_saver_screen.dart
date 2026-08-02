import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'status_saver_controller.dart';

class StatusSaverScreen extends GetView<StatusSaverController> {
  const StatusSaverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        title: Text('Status Saver', style: openSansBold.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refreshStatuses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: Obx(() {
        if (controller.statuses.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: controller.saveSelected,
          icon: const Icon(Icons.download_rounded),
          label: Text(
            controller.selected.isEmpty
                ? 'Save all'
                : 'Save (${controller.selected.length})',
          ),
        );
      }),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.folderMissing.value) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'WhatsApp statuses not found',
                      style: openSansBold.copyWith(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open WhatsApp, view some statuses, then refresh. '
                      'Storage permission may also be required.',
                      textAlign: TextAlign.center,
                      style: openSansRegular.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: controller.refreshStatuses,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (controller.statuses.isEmpty) {
            return Center(
              child: Text(
                'No status media in folder',
                style: openSansMedium.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${controller.statuses.length} statuses',
                        style: openSansMedium.copyWith(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.selectAll,
                      child: const Text('Select all'),
                    ),
                    TextButton(
                      onPressed: controller.clearSelection,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: controller.statuses.length,
                  itemBuilder: (context, index) {
                    final item = controller.statuses[index];
                    final path = item.file.path;
                    final isSelected = controller.selected.contains(path);

                    return GestureDetector(
                      onTap: () => controller.toggleSelect(path),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppUi.radiusSm),
                            child: item.isVideo
                                ? ColoredBox(
                                    color: Colors.black87,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Video',
                                          style: openSansMedium.copyWith(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Image.file(
                                    item.file,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const ColoredBox(
                                      color: Color(0xFFE0E0E0),
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppUi.radiusSm),
                                border: Border.all(
                                  color: AppUi.brandBlue,
                                  width: 3,
                                ),
                                color: AppUi.brandBlue.withValues(alpha: 0.22),
                              ),
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
