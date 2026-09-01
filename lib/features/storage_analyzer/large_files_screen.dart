import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'file_preview_thumb.dart';
import 'storage_analyzer_controller.dart';
import 'storage_tool_gate.dart';

class LargeFilesScreen extends StatefulWidget {
  const LargeFilesScreen({super.key});

  @override
  State<LargeFilesScreen> createState() => _LargeFilesScreenState();
}

class _LargeFilesScreenState extends State<LargeFilesScreen> {
  late final StorageAnalyzerController controller;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<StorageAnalyzerController>();
    // First paint the route, then permission + scan (never block Get.toNamed).
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    controller.cancelLargeFilesScan();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;

    await waitForRouteTransition(context);
    if (!mounted) return;

    final ok = await ensureStorageToolAccess(
      title: 'Storage Access Required',
      message: 'To find large files, we need permission to scan your storage.',
    );
    if (!mounted) return;
    if (ok) {
      if (controller.largeFiles.isEmpty &&
          !controller.isScanningLargeFiles.value) {
        controller.scanLargeFiles();
      }
    }
  }

  Future<void> _rescan() async {
    final ok = await ensureStorageToolAccess(
      title: 'Storage Access Required',
      message: 'To find large files, we need permission to scan your storage.',
    );
    if (!mounted || !ok) return;
    controller.scanLargeFiles();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leadingWidth: 56,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: Text('Large Files', style: openSansBold.copyWith(fontSize: 17)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Rescan',
              onPressed: _rescan,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isScanningLargeFiles.value) {
            return StorageScanLoader(
              percent: controller.scanPercent.value,
              indeterminate: controller.scanIndeterminate.value,
              title: 'Scanning large files…',
              status: controller.scanStatus.value,
              filesScanned: controller.filesFound.value,
              color: AppUi.brandBlue,
            );
          }

          if (controller.largeFiles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_off_outlined,
                        size: 56,
                        color: scheme.onSurface.withValues(alpha: 0.28)),
                    const SizedBox(height: 12),
                    Text('No large files found',
                        style: openSansSemiBold.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'Nothing over 10 MB turned up.',
                      style: openSansRegular.copyWith(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            physics: const ClampingScrollPhysics(),
            cacheExtent: 250,
            addAutomaticKeepAlives: false,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: controller.largeFiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final file = controller.largeFiles[index];
              final size = controller.largeFileSizes[file.path] ?? 0;
              return _LargeFileTile(
                file: file,
                sizeLabel: controller.formatSize(size),
                folderLabel: _folderName(file.path),
                onPreview: () => _openPreview(context, file),
                onDelete: () => _confirmDelete(context, file),
              );
            },
          );
        }),
      ),
    );
  }

  String _folderName(String path) {
    final parts = path.split('/');
    if (parts.length > 1) return parts[parts.length - 2];
    return '';
  }

  Future<void> _openPreview(BuildContext context, File file) async {
    final scheme = Theme.of(context).colorScheme;
    final name = file.path.split('/').last;
    final size = controller.formatSize(controller.largeFileSizes[file.path] ?? 0);
    final isImage = FilePreviewThumb.isImage(file.path);
    final isVideo = FilePreviewThumb.isVideo(file.path);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: isImage
                      ? Image.file(file, fit: BoxFit.contain, cacheWidth: 900)
                      : isVideo
                          ? FilePreviewThumb(file: file, size: 280, radius: 0)
                          : ColoredBox(
                              color: scheme.onSurface.withValues(alpha: 0.05),
                              child: Center(
                                child: FilePreviewThumb(
                                    file: file, size: 72, radius: 16),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 12),
              Text(name,
                  textAlign: TextAlign.center,
                  style: openSansSemiBold.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(size,
                  style: openSansRegular.copyWith(
                    fontSize: 12.5,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  )),
              const SizedBox(height: 6),
              Text(
                file.path,
                textAlign: TextAlign.center,
                style: openSansRegular.copyWith(
                  fontSize: 11,
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, File file) async {
    final scheme = Theme.of(context).colorScheme;
    final name = file.path.split('/').last;
    final size =
        controller.formatSize(controller.largeFileSizes[file.path] ?? 0);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text('Delete file?', style: openSansBold.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              FilePreviewThumb(file: file, size: 88, radius: 14),
              const SizedBox(height: 12),
              Text(name,
                  textAlign: TextAlign.center,
                  style: openSansSemiBold.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                size,
                style: openSansRegular.copyWith(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;
    try {
      await controller.deleteFile(file);
      controller.largeFiles.removeWhere((f) => f.path == file.path);
      controller.largeFileSizes.remove(file.path);
      Get.snackbar(
        'Deleted',
        'File removed',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Could not delete file',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    }
  }
}

class _LargeFileTile extends StatelessWidget {
  final File file;
  final String sizeLabel;
  final String folderLabel;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  const _LargeFileTile({
    required this.file,
    required this.sizeLabel,
    required this.folderLabel,
    required this.onPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = file.path.split('/').last;

    return SizedBox(
      height: 76,
      child: Material(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.1)),
        ),
        child: InkWell(
          onTap: onPreview,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
            child: Row(
              children: [
                FilePreviewThumb(file: file, size: 52, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: openSansSemiBold.copyWith(
                            fontSize: 13.5, height: 1.15),
                        strutStyle: const StrutStyle(
                          fontSize: 13.5,
                          height: 1.15,
                          forceStrutHeight: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppUi.brandBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sizeLabel,
                              style: openSansSemiBold.copyWith(
                                color: AppUi.brandBlue,
                                fontSize: 10.5,
                                height: 1.1,
                              ),
                            ),
                          ),
                          if (folderLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'in $folderLabel',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: openSansRegular.copyWith(
                                  fontSize: 11.5,
                                  height: 1.15,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                                strutStyle: const StrutStyle(
                                  fontSize: 11.5,
                                  height: 1.15,
                                  forceStrutHeight: true,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: const EdgeInsets.all(8),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
