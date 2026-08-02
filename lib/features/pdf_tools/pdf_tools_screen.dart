import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'pdf_tools_controller.dart';

class PdfToolsScreen extends GetView<PdfToolsController> {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        title: Text('PDF Tools', style: openSansBold.copyWith(fontSize: 18)),
        actions: [
          Obx(() {
            if (controller.images.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Clear',
              onPressed: controller.clearImages,
              icon: const Icon(Icons.clear_all_rounded),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pick images and combine them into a single PDF.',
                      style: openSansRegular.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          controller.isWorking.value ? null : controller.pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Pick images'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: controller.images.isEmpty
                    ? Center(
                        child: Text(
                          'No images selected',
                          style: openSansMedium.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: controller.images.length,
                        itemBuilder: (context, index) {
                          final file = controller.images[index];
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppUi.radiusSm),
                                child: Image.file(file, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => controller.removeImage(index),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (controller.lastPdfPath.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    controller.lastPdfPath.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: openSansMedium.copyWith(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controller.isWorking.value ||
                                controller.images.isEmpty
                            ? null
                            : controller.buildPdf,
                        child: const Text('Save PDF'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: controller.isWorking.value ||
                                controller.images.isEmpty
                            ? null
                            : controller.buildAndShare,
                        icon: controller.isWorking.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
