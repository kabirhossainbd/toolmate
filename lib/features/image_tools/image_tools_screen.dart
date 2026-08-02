import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'image_tools_controller.dart';

class ImageToolsScreen extends GetView<ImageToolsController> {
  const ImageToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        title: Text('Image Tools', style: openSansBold.copyWith(fontSize: 18)),
      ),
      body: SafeArea(
        child: Obx(() {
          final original = controller.originalFile.value;
          final compressed = controller.compressedFile.value;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Compress images to quality 70 and compare sizes.',
                style: openSansRegular.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.isWorking.value ? null : controller.pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Pick image'),
              ),
              if (original != null) ...[
                const SizedBox(height: 20),
                _PreviewCard(
                  title: 'Original',
                  sizeLabel: controller.formatSize(controller.originalBytes.value),
                  child: Image.file(original, fit: BoxFit.cover, height: 180),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: controller.isWorking.value ? null : () => controller.compress(),
                  icon: controller.isWorking.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.compress_rounded),
                  label: const Text('Compress (quality 70)'),
                ),
              ],
              if (compressed != null) ...[
                const SizedBox(height: 20),
                _PreviewCard(
                  title: 'Compressed',
                  sizeLabel:
                      '${controller.formatSize(controller.compressedBytes.value)}'
                      '${controller.savingsPercent > 0 ? '  ·  −${controller.savingsPercent.toStringAsFixed(0)}%' : ''}',
                  child: Image.file(compressed, fit: BoxFit.cover, height: 180),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: controller.isWorking.value ? null : controller.saveResult,
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save result'),
                ),
              ],
              if (controller.savedPath.value.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  controller.savedPath.value,
                  style: openSansMedium.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String sizeLabel;
  final Widget child;

  const _PreviewCard({
    required this.title,
    required this.sizeLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppUi.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(title, style: openSansSemiBold),
                const Spacer(),
                Text(
                  sizeLabel,
                  style: openSansMedium.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
