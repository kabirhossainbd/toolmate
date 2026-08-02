import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'clipboard_controller.dart';
import 'clipboard_item.dart';

class ClipboardScreen extends GetView<ClipboardController> {
  const ClipboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Get.back(),
        ),
        title: Text('Clipboard', style: openSansBold.copyWith(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'Paste from clipboard',
            icon: const Icon(Icons.content_paste_go_rounded),
            onPressed: () async {
              await controller.captureClipboard();
              Get.snackbar(
                'Updated',
                'Checked system clipboard',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 1),
                margin: const EdgeInsets.all(12),
                borderRadius: 12,
              );
            },
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppUi.brandDeep.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'While this screen is open, new copied text is saved automatically. Tap an item to copy it again.',
                style: openSansRegular.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (!controller.isReady.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.items;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.content_paste_off_rounded,
                          size: 48,
                          color: scheme.onSurface.withValues(alpha: 0.28),
                        ),
                        const SizedBox(height: 12),
                        Text('No history yet',
                            style: openSansSemiBold.copyWith(fontSize: 15)),
                        const SizedBox(height: 6),
                        Text(
                          'Copy any text, then tap the paste button above.',
                          textAlign: TextAlign.center,
                          style: openSansRegular.copyWith(
                            fontSize: 13,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: controller.captureClipboard,
                          icon: const Icon(Icons.content_paste_go_rounded),
                          label: const Text('Paste now'),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ClipboardTile(
                  item: list[i],
                  onCopy: () => controller.copyAgain(list[i]),
                  onDelete: () => controller.deleteItem(list[i].id),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All saved clipboard items will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.clearAll();
  }
}

class _ClipboardTile extends StatelessWidget {
  final ClipboardItem item;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _ClipboardTile({
    required this.item,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onCopy();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: openSansRegular.copyWith(
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM d · h:mm a').format(item.createdAt),
                      style: openSansRegular.copyWith(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: onCopy,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
