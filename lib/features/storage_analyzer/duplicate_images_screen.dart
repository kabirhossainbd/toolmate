import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'file_preview_thumb.dart';
import 'storage_analyzer_controller.dart';
import 'storage_tool_gate.dart';

class DuplicateImagesScreen extends StatefulWidget {
  const DuplicateImagesScreen({super.key});

  @override
  State<DuplicateImagesScreen> createState() => _DuplicateImagesScreenState();
}

class _DuplicateImagesScreenState extends State<DuplicateImagesScreen> {
  late final StorageAnalyzerController controller;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<StorageAnalyzerController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    controller.cancelDuplicateImagesScan();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapped || !mounted) return;
    _bootstrapped = true;
    await waitForRouteTransition(context);
    if (!mounted) return;

    final ok = await ensureStorageToolAccess(
      title: 'Gallery Access Required',
      message:
          'To find duplicate images, we need permission to access your gallery.',
      gallery: true,
    );
    if (!mounted) return;
    if (ok) {
      if (controller.duplicateImages.isEmpty &&
          !controller.isScanningImages.value) {
        controller.findDuplicateImages();
      }
    }
  }

  Future<void> _rescan() async {
    final ok = await ensureStorageToolAccess(
      title: 'Gallery Access Required',
      message:
          'To find duplicate images, we need permission to access your gallery.',
      gallery: true,
    );
    if (!mounted || !ok) return;
    controller.findDuplicateImages();
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
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        title: Text('Duplicate Images',
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
        if (controller.isScanningImages.value) {
          return StorageScanLoader(
            percent: controller.scanPercent.value,
            indeterminate: controller.scanIndeterminate.value,
            title: 'Analyzing images…',
            status: controller.scanStatus.value,
            filesScanned: controller.filesFound.value,
            color: AppUi.brandTeal,
          );
        }

        if (controller.duplicateImages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 64, color: Colors.green.withValues(alpha: 0.55)),
                  const SizedBox(height: 14),
                  Text('No duplicate images',
                      style: openSansSemiBold.copyWith(fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    'Each photo appears only once — nothing to clean.',
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
          itemCount: controller.duplicateImages.length,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemBuilder: (context, index) {
            final group = controller.duplicateImages[index];
            return _ImageGroupCard(
              groupIndex: index,
              group: group,
              onPreview: (asset) => _openPreview(context, group, asset),
              onDelete: (asset) => _confirmDelete(context, asset, group),
            );
          },
        );
      }),
      ),
    );
  }

  Future<void> _openPreview(
    BuildContext context,
    List<AssetEntity> group,
    AssetEntity selected,
  ) async {
    final start = group.indexWhere((a) => a.id == selected.id).clamp(0, group.length - 1);
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return _ImagePreviewDialog(
          group: group,
          initialIndex: start,
          onDelete: (asset) async {
            Navigator.pop(ctx);
            await _confirmDelete(context, asset, group);
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AssetEntity asset,
    List<AssetEntity> group,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final sizeLabel = await _assetSizeLabel(asset);
    if (!context.mounted) return;
    final dateLabel =
        DateFormat('MMM d, y · h:mm a').format(asset.createDateTime);

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
                  'Only this photo will be removed. Other copies stay.',
                  textAlign: TextAlign.center,
                  style: openSansRegular.copyWith(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AssetEntityImage(
                      asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize(512, 512),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.title ?? 'Untitled',
                        style: openSansSemiBold.copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((asset.relativePath ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          asset.relativePath!,
                          style: openSansRegular.copyWith(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '$sizeLabel · $dateLabel',
                        style: openSansRegular.copyWith(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '${asset.width}×${asset.height}',
                        style: openSansRegular.copyWith(
                          fontSize: 12,
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
      await controller.deleteAsset(asset);
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
        'Could not delete this image',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    }
  }

  Future<String> _assetSizeLabel(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null) return '—';
      return controller.formatSize(await file.length());
    } catch (_) {
      return '—';
    }
  }
}

class _ImageGroupCard extends StatelessWidget {
  final int groupIndex;
  final List<AssetEntity> group;
  final void Function(AssetEntity asset) onPreview;
  final void Function(AssetEntity asset) onDelete;

  const _ImageGroupCard({
    required this.groupIndex,
    required this.group,
    required this.onPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppUi.brandTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.collections_rounded,
                      color: AppUi.brandTeal, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Same photo · ${group.length} copies',
                        style: openSansSemiBold.copyWith(fontSize: 14),
                      ),
                      Text(
                        'Tap to preview · Keep one, delete extras',
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
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: group.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final asset = group[index];
                return _ImageCopyTile(
                  key: ValueKey(asset.id),
                  asset: asset,
                  keepLabel: index == 0,
                  onTap: () => onPreview(asset),
                  onDelete: () => onDelete(asset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCopyTile extends StatelessWidget {
  final AssetEntity asset;
  final bool keepLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ImageCopyTile({
    super.key,
    required this.asset,
    required this.keepLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (asset.title ?? 'Photo').trim();
    final shortName = title.isEmpty ? 'Photo' : title;
    final folder = (asset.relativePath ?? '')
        .replaceAll(RegExp(r'^/+|/+$'), '')
        .split('/')
        .where((s) => s.isNotEmpty)
        .lastOrNull;
    final subtitle = folder == null || folder.isEmpty ? shortName : '$folder/$shortName';

    // Rigid square — name is overlay inside the image so long text
    // cannot change layout height (no blink / jump).
    return SizedBox(
      width: 112,
      height: 112,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.grey.shade300),
                AssetEntityImage(
                  asset,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize(224, 224),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, sync) {
                    // Skip fade-in animation that causes blink.
                    if (sync || frame != null) return child;
                    return const SizedBox.expand();
                  },
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 28),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: keepLabel
                          ? AppUi.brandTeal
                          : Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      keepLabel ? 'Keep' : 'Copy',
                      style: openSansSemiBold.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.redAccent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 28,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: openSansSemiBold.copyWith(
                        color: Colors.white,
                        fontSize: 10.5,
                        height: 1.1,
                      ),
                      strutStyle: const StrutStyle(
                        fontSize: 10.5,
                        height: 1.1,
                        forceStrutHeight: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreviewDialog extends StatefulWidget {
  final List<AssetEntity> group;
  final int initialIndex;
  final Future<void> Function(AssetEntity asset) onDelete;

  const _ImagePreviewDialog({
    required this.group,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.group[_index];
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              controller: _page,
              itemCount: widget.group.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AssetEntityImage(
                  widget.group[i],
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize(1200, 1200),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_index + 1} / ${widget.group.length}  ·  ${asset.title ?? 'Photo'}',
            style: openSansRegular.copyWith(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => widget.onDelete(asset),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete this copy'),
          ),
        ],
      ),
    );
  }
}
