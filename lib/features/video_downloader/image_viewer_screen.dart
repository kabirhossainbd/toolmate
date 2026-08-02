import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'video_model.dart';

class ImageViewerScreen extends StatelessWidget {
  final VideoModel media;

  const ImageViewerScreen({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final file = File(media.savePath);
    final exists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          media.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: exists
            ? InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const _MissingMedia(
                    message: 'Could not load image',
                  ),
                ),
              )
            : media.thumbnailUrl.isNotEmpty
                ? InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      media.thumbnailUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const _MissingMedia(
                        message: 'Image file not found',
                      ),
                    ),
                  )
                : const _MissingMedia(message: 'Image file not found'),
      ),
    );
  }
}

class _MissingMedia extends StatelessWidget {
  final String message;
  const _MissingMedia({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
