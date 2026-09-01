import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'file_preview_thumb.dart';
import 'storage_analyzer_controller.dart';
import 'storage_tool_gate.dart';

class DuplicateFilesScreen extends StatefulWidget {
  const DuplicateFilesScreen({super.key});

  @override
  State<DuplicateFilesScreen> createState() => _DuplicateFilesScreenState();
}

class _DuplicateFilesScreenState extends State<DuplicateFilesScreen> {
  late final StorageAnalyzerController controller;
  bool _bootstrapped = false;

  bool _isImage(String path) => FilePreviewThumb.isImage(path);

  bool _isMedia(String path) =>
      FilePreviewThumb.isImage(path) || FilePreviewThumb.isVideo(path);

  @override
  void initState() {
    super.initState();
    controller = Get.find<StorageAnalyzerController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    controller.cancelDuplicateFilesScan();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;
    await waitForRouteTransition(context);
    if (!mounted) return;

    final ok = await ensureStorageToolAccess(
      title: 'Storage Access Required',
      message:
          'To find duplicate files, we need permission to scan your storage.',
    );
    if (!mounted) return;
    if (ok) {
      if (controller.duplicateFilesList.isEmpty &&
          !controller.isScanningDuplicates.value) {
        controller.findAllDuplicateFiles();
      }
    }
  }

  Future<void> _rescan() async {
    final ok = await ensureStorageToolAccess(
      title: 'Storage Access Required',
      message:
          'To find duplicate files, we need permission to scan your storage.',
    );
    if (!mounted || !ok) return;
    controller.findAllDuplicateFiles();
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
        title: Text('Duplicate Files',
            style: openSansBold.copyWith(fontSize: 17)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Rescan',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _rescan,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isScanningDuplicates.value) {
            return StorageScanLoader(
              percent: controller.scanPercent.value,
              indeterminate: controller.scanIndeterminate.value,
              title: 'Finding duplicates…',
              status: controller.scanStatus.value,
              filesScanned: controller.filesFound.value,
              color: AppUi.brandOrange,
            );
          }

          if (controller.duplicateFilesList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 64,
                        color: Colors.green.withValues(alpha: 0.55)),
                    const SizedBox(height: 14),
                    Text('No duplicate files',
                        style: openSansSemiBold.copyWith(fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      'No exact copies found on your storage.',
                      textAlign: TextAlign.center,
                      style: openSansRegular.copyWith(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const ClampingScrollPhysics(),
            cacheExtent: 220,
            addAutomaticKeepAlives: false,
            itemCount: controller.duplicateFilesList.length,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemBuilder: (context, index) {
              final group = controller.duplicateFilesList[index];
              return _FileGroupCard(
                key: ValueKey(group.map((f) => f.path).join('|')),
                group: group,
                formatSize: controller.formatSize,
                onPreview: (file) => _openPreview(context, file),
                onDelete: (file) => _confirmDelete(context, file),
              );
            },
          );
        }),
      ),
    );
  }

  Future<void> _openPreview(BuildContext context, File file) async {
    final scheme = Theme.of(context).colorScheme;
    final name = file.path.split('/').last;
    final size = file.existsSync()
        ? controller.formatSize(file.lengthSync())
        : '—';
    final isImage = _isImage(file.path);
    final isMedia = _isMedia(file.path);

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMedia)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: isImage
                        ? Image.file(
                            file,
                            fit: BoxFit.contain,
                            cacheWidth: 800,
                            errorBuilder: (_, _, _) => FilePreviewThumb(
                                file: file, size: 120, radius: 0),
                          )
                        : FilePreviewThumb(file: file, size: 280, radius: 0),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: AppUi.brandOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FilePreviewThumb(file: file, size: 64, radius: 14),
                  ),
                ),
              const SizedBox(height: 14),
              Text(name,
                  style: openSansSemiBold.copyWith(fontSize: 15),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                size,
                style: openSansRegular.copyWith(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                file.path,
                textAlign: TextAlign.center,
                style: openSansRegular.copyWith(
                  fontSize: 11.5,
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 16),
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
    final size = file.existsSync()
        ? controller.formatSize(file.lengthSync())
        : '—';
    final isMedia = _isMedia(file.path);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
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
                Text('Delete this copy?',
                    style: openSansBold.copyWith(fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  'Only this file will be deleted. Other copies stay on your device.',
                  textAlign: TextAlign.center,
                  style: openSansRegular.copyWith(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 16),
                if (isMedia)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: FilePreviewThumb.isImage(file.path)
                          ? Image.file(
                              file,
                              fit: BoxFit.cover,
                              cacheWidth: 600,
                              errorBuilder: (_, _, _) => FilePreviewThumb(
                                  file: file, size: 160, radius: 0),
                            )
                          : FilePreviewThumb(file: file, size: 220, radius: 0),
                    ),
                  )
                else
                  FilePreviewThumb(file: file, size: 72, radius: 14),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: openSansSemiBold.copyWith(fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        size,
                        style: openSansRegular.copyWith(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.path,
                        style: openSansRegular.copyWith(
                          fontSize: 11.5,
                          height: 1.35,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
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
        );
      },
    );

    if (ok != true) return;
    try {
      await controller.deleteFile(file);
      Get.snackbar(
        'Deleted',
        'One copy removed. Others kept.',
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

class _FileGroupCard extends StatelessWidget {
  final List<File> group;
  final String Function(int bytes) formatSize;
  final void Function(File file) onPreview;
  final void Function(File file) onDelete;

  const _FileGroupCard({
    super.key,
    required this.group,
    required this.formatSize,
    required this.onPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeLabel = group.isNotEmpty && group.first.existsSync()
        ? formatSize(group.first.lengthSync())
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppUi.brandOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_all_rounded,
                      color: AppUi.brandOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${group.length} identical copies',
                        style: openSansSemiBold.copyWith(fontSize: 14),
                      ),
                      Text(
                        '$sizeLabel each · tap a row to preview',
                        style: openSansRegular.copyWith(
                          fontSize: 11.5,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(group.length, (index) {
            final file = group[index];
            final name = file.path.split('/').last;
            final parts = file.path.split('/');
            final folder = parts.length > 1 ? parts[parts.length - 2] : '';

            return SizedBox(
              height: 72,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onPreview(file),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                    child: Row(
                      children: [
                        FilePreviewThumb(file: file, size: 48, radius: 10),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: openSansSemiBold.copyWith(
                                        fontSize: 13,
                                        height: 1.15,
                                      ),
                                      strutStyle: const StrutStyle(
                                        fontSize: 13,
                                        height: 1.15,
                                        forceStrutHeight: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: index == 0
                                          ? AppUi.brandTeal
                                              .withValues(alpha: 0.15)
                                          : scheme.onSurface
                                              .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      index == 0 ? 'Keep' : 'Copy',
                                      style: openSansSemiBold.copyWith(
                                        fontSize: 10,
                                        height: 1.1,
                                        color: index == 0
                                            ? AppUi.brandTeal
                                            : scheme.onSurface
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '/$folder/',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: openSansRegular.copyWith(
                                  fontSize: 11.5,
                                  height: 1.15,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.5),
                                ),
                                strutStyle: const StrutStyle(
                                  fontSize: 11.5,
                                  height: 1.15,
                                  forceStrutHeight: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete this copy',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                              minWidth: 40, minHeight: 40),
                          padding: const EdgeInsets.all(8),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => onDelete(file),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
