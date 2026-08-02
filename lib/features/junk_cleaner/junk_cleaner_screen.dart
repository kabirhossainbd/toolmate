import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'junk_cleaner_controller.dart';

class JunkCleanerScreen extends GetView<JunkCleanerController> {
  const JunkCleanerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        title: Text('Junk Cleaner', style: openSansBold.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Rescan',
            onPressed: () => controller.scan(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isScanning.value && controller.totalBytes == 0) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: AppUi.accentGradient(AppUi.brandTeal),
                    borderRadius: BorderRadius.circular(AppUi.radiusLg),
                    boxShadow: AppUi.softGlow(AppUi.brandTeal),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Junk found',
                        style: openSansMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.formatSize(controller.totalBytes),
                        style: openSansExtraBold.copyWith(
                          color: Colors.white,
                          fontSize: 36,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SizeTile(
                  icon: Icons.timelapse_rounded,
                  title: 'Temporary files',
                  size: controller.formatSize(controller.tempBytes.value),
                ),
                const SizedBox(height: 10),
                _SizeTile(
                  icon: Icons.cached_rounded,
                  title: 'App cache',
                  size: controller.formatSize(controller.cacheBytes.value),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: controller.isCleaning.value ||
                          controller.isScanning.value ||
                          controller.totalBytes == 0
                      ? null
                      : controller.clean,
                  icon: controller.isCleaning.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cleaning_services_rounded),
                  label: Text(
                    controller.isCleaning.value ? 'Cleaning…' : 'Clean',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SizeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String size;

  const _SizeTile({
    required this.icon,
    required this.title,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppUi.radiusMd),
      child: ListTile(
        leading: Icon(icon, color: AppUi.brandTeal),
        title: Text(title, style: openSansSemiBold),
        trailing: Text(
          size,
          style: openSansBold.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
