import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/style.dart';
import 'storage_analyzer_controller.dart';
import 'storage_tool_gate.dart';

/// Self-contained folder browser — local state only (no shared Obx list),
/// so opening from Storage Analyzer never blinks or freezes on stale scans.
class StorageExplorerScreen extends StatefulWidget {
  final String initialPath;

  const StorageExplorerScreen({
    super.key,
    this.initialPath = '/storage/emulated/0',
  });

  @override
  State<StorageExplorerScreen> createState() => _StorageExplorerScreenState();
}

class _StorageExplorerScreenState extends State<StorageExplorerScreen> {
  static const _root = '/storage/emulated/0';

  late String _path;
  final List<String> _history = [];

  List<FileSystemEntityInfo> _items = const [];
  bool _loading = true;
  bool _failed = false;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _path = widget.initialPath;
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await waitForRouteTransition(context);
    if (!mounted) return;

    final ok = await ensureStorageToolAccess(
      title: 'Storage Access Required',
      message: 'To analyze folders, we need permission to scan your storage.',
    );
    if (!mounted) return;
    _load(_path);
  }

  Future<void> _load(String path) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _failed = false;
      // Keep previous items visible until new ones arrive — avoids empty blink.
    });

    try {
      final raw = await compute(_listFolderIsolate, path)
          .timeout(const Duration(seconds: 8), onTimeout: () => <Map<String, Object?>>[]);

      if (!mounted || gen != _loadGen) return;

      setState(() {
        _items = raw
            .map(
              (e) => FileSystemEntityInfo(
                name: e['name']! as String,
                path: e['path']! as String,
                isFolder: e['isFolder']! as bool,
                size: e['size']! as int,
                extension: e['extension'] as String?,
              ),
            )
            .toList(growable: false);
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _items = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  String get _title {
    if (_path == _root || _path == '/sdcard') return 'Storage Explorer';
    final name = _path.split('/').where((s) => s.isNotEmpty).lastOrNull;
    return name ?? 'Storage Explorer';
  }

  void _openFolder(String nextPath) {
    _history.add(_path);
    setState(() => _path = nextPath);
    _load(nextPath);
  }

  Future<bool> _goUpOrPop() async {
    if (_history.isNotEmpty) {
      final prev = _history.removeLast();
      setState(() => _path = prev);
      _load(prev);
      return false;
    }
    return true;
  }

  Future<void> _onBackPressed() async {
    if (await _goUpOrPop() && mounted) Get.back();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (math.log(bytes) / math.log(1024)).floor().clamp(0, suffixes.length - 1);
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goUpOrPop();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          leadingWidth: 56,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _onBackPressed,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          ),
          title: Text(_title, style: openSansBold.copyWith(fontSize: 17)),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : () => _load(_path),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  _path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: openSansRegular.copyWith(
                    fontSize: 12.5,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              if (_loading)
                const LinearProgressIndicator(minHeight: 2)
              else
                const SizedBox(height: 2),
              Expanded(child: _buildBody(scheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (!_loading && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _failed ? Icons.error_outline_rounded : Icons.folder_off_outlined,
                size: 56,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 14),
              Text(
                _failed ? 'Could not open this folder' : 'No items found',
                style: openSansSemiBold.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                _failed
                    ? 'Check All files access permission, then retry.'
                    : 'This folder is empty.',
                textAlign: TextAlign.center,
                style: openSansRegular.copyWith(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => _load(_path),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      cacheExtent: 200,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemCount: _items.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _FileTile(
          key: ValueKey(item.path),
          item: item,
          sizeLabel: item.isFolder ? 'Folder' : _formatSize(item.size),
          onOpen: item.isFolder ? () => _openFolder(item.path) : null,
          onDelete: item.isFolder ? null : () => _confirmDelete(item),
        );
      },
    );
  }

  void _confirmDelete(FileSystemEntityInfo item) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Delete ${item.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _performDelete(item);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(FileSystemEntityInfo item) async {
    try {
      final controller = Get.find<StorageAnalyzerController>();
      // Delete the file directly — avoid controller listFolderContent side effects.
      final file = File(item.path);
      if (await file.exists()) {
        await file.delete();
      } else {
        await controller.deleteFileSystemEntity(item.path);
      }
      if (!mounted) return;
      setState(() {
        _items = _items.where((e) => e.path != item.path).toList(growable: false);
      });
      Get.snackbar(
        'Deleted',
        item.name,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'Could not delete item',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    }
  }
}

/// Runs off the UI isolate so opening Explorer never freezes the route transition.
List<Map<String, Object?>> _listFolderIsolate(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return const [];

  final items = <Map<String, Object?>>[];
  try {
    final entities = dir.listSync(recursive: false, followLinks: false);
    for (final entity in entities) {
      final name = entity.path.split('/').last;
      if (name.startsWith('.')) continue;

      if (entity is Directory) {
        items.add({
          'name': name,
          'path': entity.path,
          'isFolder': true,
          'size': 0,
          'extension': null,
        });
      } else if (entity is File) {
        var size = 0;
        try {
          size = entity.lengthSync();
        } catch (_) {}
        items.add({
          'name': name,
          'path': entity.path,
          'isFolder': false,
          'size': size,
          'extension': name.contains('.')
              ? name.split('.').last.toLowerCase()
              : null,
        });
      }
    }
  } catch (_) {
    return const [];
  }

  items.sort((a, b) {
    final aFolder = a['isFolder']! as bool;
    final bFolder = b['isFolder']! as bool;
    if (aFolder && !bFolder) return -1;
    if (!aFolder && bFolder) return 1;
    return (a['name']! as String)
        .toLowerCase()
        .compareTo((b['name']! as String).toLowerCase());
  });
  return items;
}

class _FileTile extends StatelessWidget {
  final FileSystemEntityInfo item;
  final String sizeLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const _FileTile({
    super.key,
    required this.item,
    required this.sizeLabel,
    this.onOpen,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _TypeIcon(item: item),
      title: Text(
        item.name,
        style: openSansSemiBold.copyWith(fontSize: 14.5),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        sizeLabel,
        style: openSansRegular.copyWith(
          fontSize: 12.5,
          color: Colors.grey[600],
        ),
      ),
      trailing: onDelete == null
          ? (item.isFolder
              ? Icon(Icons.chevron_right_rounded, color: Colors.grey[400])
              : null)
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 22),
              onPressed: onDelete,
            ),
      onTap: onOpen,
    );
  }
}

/// Icons only — Image.file thumbs were decoding on the UI thread and freezing navigation.
class _TypeIcon extends StatelessWidget {
  final FileSystemEntityInfo item;

  const _TypeIcon({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isFolder) {
      return const Icon(Icons.folder_rounded, color: Colors.amber, size: 40);
    }

    final ext = item.extension;
    IconData iconData = Icons.insert_drive_file_rounded;
    Color color = Colors.grey;

    if (ext != null) {
      if (const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'}
          .contains(ext)) {
        iconData = Icons.image_rounded;
        color = Colors.blue;
      } else if (const {'mp4', 'mkv', 'avi', 'mov', 'webm'}.contains(ext)) {
        iconData = Icons.videocam_rounded;
        color = Colors.purple;
      } else if (const {'mp3', 'wav', 'm4a', 'flac', 'aac'}.contains(ext)) {
        iconData = Icons.audiotrack_rounded;
        color = Colors.orange;
      } else if (const {'pdf', 'doc', 'docx', 'txt', 'epub'}.contains(ext)) {
        iconData = Icons.description_rounded;
        color = Colors.red;
      } else if (ext == 'apk') {
        iconData = Icons.android_rounded;
        color = Colors.green;
      } else if (const {'zip', 'rar', '7z'}.contains(ext)) {
        iconData = Icons.archive_rounded;
        color = Colors.brown;
      }
    }

    return Icon(iconData, color: color, size: 40);
  }
}
