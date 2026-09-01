import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail_gen/video_thumbnail_gen.dart';

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
///
/// Layout height is locked so long filenames / status swaps never jump the
/// column. Progress eases toward the latest percent for a smooth ring.
class StorageScanLoader extends StatefulWidget {
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
  State<StorageScanLoader> createState() => _StorageScanLoaderState();
}

class _StorageScanLoaderState extends State<StorageScanLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  double _painted = 0; // 0–1

  @override
  void initState() {
    super.initState();
    _painted = (widget.percent / 100).clamp(0.0, 1.0);
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _progressAnim = AlwaysStoppedAnimation(_painted);
    _progressCtrl.addListener(() {
      _painted = _progressAnim.value;
    });
  }

  @override
  void didUpdateWidget(covariant StorageScanLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.indeterminate) return;
    final next = (widget.percent / 100).clamp(0.0, 1.0);
    if ((next - _painted).abs() < 0.0005) return;
    _animateTo(next);
  }

  void _animateTo(double target) {
    final begin = _painted;
    _progressAnim = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOutCubic),
    );
    _progressCtrl
      ..duration = Duration(
        milliseconds: (280 + ((target - begin).abs() * 420)).round().clamp(280, 700),
      )
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  String get _statusLabel {
    final raw = widget.status.trim();
    if (raw.isEmpty) return 'Please wait…';
    // Prefer filename only when a path sneaks into status.
    final base = raw.contains('/') ? raw.split('/').last : raw;
    if (base.length <= 42) return base;
    return '${base.substring(0, 39)}…';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusStyle = openSansRegular.copyWith(
      fontSize: 13,
      height: 1.25,
      color: scheme.onSurface.withValues(alpha: 0.55),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: widget.indeterminate
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 112,
                          height: 112,
                          child: CircularProgressIndicator(
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            color: widget.color,
                            backgroundColor:
                                widget.color.withValues(alpha: 0.14),
                          ),
                        ),
                        Text(
                          '…',
                          style: openSansBold.copyWith(fontSize: 22, height: 1),
                        ),
                      ],
                    )
                  : AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (context, _) {
                        final value = _progressAnim.value.clamp(0.0, 1.0);
                        final pct = (value * 100).round().clamp(0, 100);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 112,
                              height: 112,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                color: widget.color,
                                backgroundColor:
                                    widget.color.withValues(alpha: 0.14),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: openSansBold.copyWith(
                                fontSize: 22,
                                height: 1,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 22),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: openSansSemiBold.copyWith(fontSize: 16, height: 1.2),
            ),
            const SizedBox(height: 10),
            // Fixed slot — filename length never changes column height.
            SizedBox(
              height: 18,
              width: double.infinity,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) {
                  return FadeTransition(opacity: anim, child: child);
                },
                layoutBuilder: (current, previous) {
                  return Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      ...previous,
                      if (current != null) current,
                    ],
                  );
                },
                child: Text(
                  _statusLabel,
                  key: ValueKey(_statusLabel),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: statusStyle,
                  strutStyle: const StrutStyle(
                    fontSize: 13,
                    height: 1.25,
                    forceStrutHeight: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Always reserve the counter row so it cannot pop layout.
            SizedBox(
              height: 16,
              child: AnimatedOpacity(
                opacity: widget.filesScanned > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '${widget.filesScanned} files checked',
                  style: openSansRegular.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    color: widget.color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
