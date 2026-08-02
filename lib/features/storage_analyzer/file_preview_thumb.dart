import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';

/// Compact file thumbnail — image/video preview or typed icon fallback.
class FilePreviewThumb extends StatelessWidget {
  final File file;
  final double size;
  final double radius;

  const FilePreviewThumb({
    super.key,
    required this.file,
    this.size = 52,
    this.radius = 12,
  });

  static const imageExt = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  static const videoExt = {
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    '3gp',
    'm4v',
  };

  static String extOf(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return '';
    return path.substring(i + 1).toLowerCase();
  }

  static bool isImage(String path) => imageExt.contains(extOf(path));
  static bool isVideo(String path) => videoExt.contains(extOf(path));

  @override
  Widget build(BuildContext context) {
    final path = file.path;
    final ext = extOf(path);

    Widget child;
    if (isImage(path)) {
      child = Image.file(
        file,
        fit: BoxFit.cover,
        width: size,
        height: size,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        frameBuilder: (context, child, frame, sync) {
          if (sync || frame != null) return child;
          return ColoredBox(color: Colors.grey.shade300);
        },
        errorBuilder: (_, _, _) => _TypeIcon(ext: ext),
      );
    } else if (isVideo(path)) {
      child = _VideoThumb(path: path, size: size, ext: ext);
    } else {
      child = _TypeIcon(ext: ext);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size,
        height: size,
        child: child,
      ),
    );
  }
}

class _VideoThumb extends StatefulWidget {
  final String path;
  final double size;
  final String ext;

  const _VideoThumb({
    required this.path,
    required this.size,
    required this.ext,
  });

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  static final _cache = <String, Uint8List?>{};
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cache.containsKey(widget.path)) {
      _bytes = _cache[widget.path];
      if (mounted) setState(() {});
      return;
    }
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: (widget.size * 3).round(),
        quality: 60,
      );
      _cache[widget.path] = data;
      if (!mounted) return;
      setState(() => _bytes = data);
    } catch (_) {
      _cache[widget.path] = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep a stable type icon underneath; never swap spinner→image (blinks).
    return Stack(
      fit: StackFit.expand,
      children: [
        _TypeIcon(ext: widget.ext),
        if (_bytes != null)
          Image.memory(
            _bytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          ),
        if (_bytes != null)
          const Center(
            child: Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 22),
          ),
      ],
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final String ext;
  const _TypeIcon({required this.ext});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (ext) {
      'mp4' || 'mkv' || 'avi' || 'mov' || 'webm' || '3gp' || 'm4v' => (
          Icons.movie_rounded,
          AppUi.brandPurple
        ),
      'apk' => (Icons.android_rounded, AppUi.brandTeal),
      'pdf' => (Icons.picture_as_pdf_rounded, Colors.redAccent),
      'zip' || 'rar' || '7z' => (Icons.folder_zip_rounded, AppUi.brandOrange),
      'mp3' || 'wav' || 'aac' || 'm4a' || 'flac' => (
          Icons.audiotrack_rounded,
          AppUi.brandPink
        ),
      'doc' || 'docx' || 'txt' => (Icons.description_rounded, AppUi.brandBlue),
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'heic' || 'heif' => (
          Icons.image_rounded,
          AppUi.brandTeal
        ),
      _ => (Icons.insert_drive_file_rounded, AppUi.brandBlue),
    };

    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Center(child: Icon(icon, color: color, size: 24)),
    );
  }
}

/// Shared scan progress UI for storage tools.
class StorageScanLoader extends StatelessWidget {
  final double percent; // 0–100
  final bool indeterminate;
  final String title;
  final String status;
  final int filesScanned;
  final Color color;

  const StorageScanLoader({
    super.key,
    required this.percent,
    required this.indeterminate,
    required this.title,
    required this.status,
    required this.filesScanned,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = indeterminate ? null : (percent / 100).clamp(0.0, 1.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 108,
              height: 108,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.14),
                    ),
                  ),
                  Text(
                    indeterminate ? '…' : '${percent.clamp(0, 100).toInt()}%',
                    style: openSansBold.copyWith(fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(title, style: openSansSemiBold.copyWith(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              status.isEmpty ? 'Please wait…' : status,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: openSansRegular.copyWith(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            if (filesScanned > 0) ...[
              const SizedBox(height: 10),
              Text(
                '$filesScanned files checked',
                style: openSansRegular.copyWith(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
