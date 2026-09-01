import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:share_plus/share_plus.dart';
import 'video_model.dart';
import 'video_player_screen.dart';
import 'image_viewer_screen.dart';
import 'social_media_service.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoDownloaderController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;

  final urlController = ''.obs;
  final textEditingController = TextEditingController();

  /// All media items found for the pasted link (multi-image posts, etc.).
  final RxList<ResolvedMedia> resolvedItems = <ResolvedMedia>[].obs;

  /// Currently selected item for save preview.
  final Rxn<ResolvedMedia> selectedMedia = Rxn<ResolvedMedia>();

  final isFetching = false.obs;
  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;

  late Box<VideoModel> historyBox;
  final RxList<VideoModel> downloadHistory = <VideoModel>[].obs;

  final _social = SocialMediaService();

  /// Kept for UI compatibility with older preview cards.
  final Rx<VideoModel?> currentVideo = Rx<VideoModel?>(null);

  List<String> get supportedPlatforms => SocialMediaService.supportedPlatforms;

  /// Index into [supportedPlatforms] for the URL in the input field (-1 = none).
  final detectedPlatformIndex = (-1).obs;

  void updatePlatformFromUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      detectedPlatformIndex.value = -1;
      return;
    }
    final platform = _social.detectPlatform(trimmed);
    detectedPlatformIndex.value = supportedPlatforms.indexOf(platform);
  }

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);
    historyBox = Hive.box<VideoModel>('video_history');
    _loadHistory();
  }

  @override
  void onClose() {
    tabController.dispose();
    textEditingController.dispose();
    super.onClose();
  }

  void _loadHistory() {
    downloadHistory.assignAll(historyBox.values.toList().reversed);
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      textEditingController.text = data.text!;
      urlController.value = data.text!;
      updatePlatformFromUrl(data.text!);
    } else {
      Get.snackbar('Clipboard', 'No text found in clipboard');
    }
  }

  void clearPreview() {
    currentVideo.value = null;
    selectedMedia.value = null;
    resolvedItems.clear();
  }

  void selectMedia(ResolvedMedia media) {
    selectedMedia.value = media;
    currentVideo.value = VideoModel(
      url: media.sourceUrl,
      title: media.title,
      thumbnailUrl: media.thumbnailUrl,
      savePath: '',
      downloadDate: DateTime.now(),
      mediaType: media.kind.name,
      platform: media.platform,
    );
  }

  Future<void> fetchVideoInfo(String url) async {
    final parsedUri = Uri.tryParse(url.trim());
    if (url.trim().isEmpty || parsedUri == null || !parsedUri.hasScheme) {
      Get.snackbar('Error', 'Please enter a valid URL');
      return;
    }

    if (SocialMediaService.isYouTubeUrl(url)) {
      Get.snackbar(
        'Not supported',
        'This platform is not supported. Paste a public Instagram, TikTok, Facebook, or X link instead.',
      );
      return;
    }

    isFetching.value = true;
    clearPreview();

    try {
      final result = await _social.resolve(url.trim());
      if (!result.isSuccess) {
        Get.snackbar(
          'Error',
          result.error ?? 'Failed to fetch media from this link.',
        );
        return;
      }

      resolvedItems.assignAll(result.items);
      selectMedia(result.items.first);

      if (result.items.length > 1) {
        Get.snackbar(
          'Multiple media found',
          '${result.items.length} items found — pick one to save.',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (_) {
      Get.snackbar('Error', 'An unexpected error occurred.');
    } finally {
      isFetching.value = false;
    }
  }

  Future<void> downloadVideo() async {
    final media = selectedMedia.value;
    if (media == null) return;
    if (!(await _requestPermissions())) return;

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${docsDir.path}/toolmate_media');
      if (!mediaDir.existsSync()) {
        await mediaDir.create(recursive: true);
      }
      final safeName = media.filename
          .replaceAll(RegExp(r'[^\w.\-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = safeName.contains('.')
          ? '${safeName.split('.').first}_$stamp.${safeName.split('.').last}'
          : '${safeName}_$stamp.${media.kind == MediaKind.video ? 'mp4' : 'jpg'}';
      final savePath = '${mediaDir.path}/$fileName';

      final dlDio = dio.Dio();
      await dlDio.download(
        media.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) downloadProgress.value = received / total;
        },
        options: dio.Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': '*/*',
          },
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
        ),
      );

      bool? saved;
      if (media.kind == MediaKind.image || media.kind == MediaKind.gif) {
        saved = await GallerySaver.saveImage(savePath, albumName: 'ToolMate');
      } else {
        saved = await GallerySaver.saveVideo(savePath, albumName: 'ToolMate');
      }

      if (saved == true) {
        final completed = VideoModel(
          url: media.sourceUrl,
          title: media.title,
          thumbnailUrl: media.thumbnailUrl,
          savePath: savePath,
          downloadDate: DateTime.now(),
          mediaType: media.kind.name,
          platform: media.platform,
        );
        await historyBox.add(completed);
        _loadHistory();
        clearPreview();
        urlController.value = '';
        textEditingController.clear();
        tabController.animateTo(1);
        // Open play / view right after save.
        openMedia(completed);
      } else {
        Get.snackbar('Error', 'Failed to save media to gallery.');
      }
    } catch (e) {
      Get.log('Download error: $e');
      Get.snackbar('Error', 'Failed to download media.');
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> shareVideo(VideoModel video) async {
    final file = File(video.savePath);
    if (file.existsSync()) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(video.savePath)], text: video.title),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(text: '${video.title}\n${video.url}'),
      );
    }
  }

  Future<void> deleteVideo(VideoModel video) async {
    await video.delete();
    final file = File(video.savePath);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    _loadHistory();
    Get.snackbar('Deleted', 'Removed successfully.');
  }

  void copyLink(VideoModel video) {
    Clipboard.setData(ClipboardData(text: video.url));
    Get.snackbar('Copied', 'Link copied to clipboard');
  }

  void playVideo(VideoModel video) => openMedia(video);

  void openMedia(VideoModel video) {
    final file = File(video.savePath);
    if (!file.existsSync() && !video.isImage) {
      Get.snackbar('Not found', 'File not found on device.');
      return;
    }

    if (video.isImage) {
      Get.to(() => ImageViewerScreen(media: video));
      return;
    }

    if (file.existsSync()) {
      Get.to(() => VideoPlayerScreen(video: video));
    } else {
      Get.snackbar('Not found', 'File not found on device.');
    }
  }

  String getFileSize(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        final mb = bytes / (1024 * 1024);
        return '${mb.toStringAsFixed(1)} MB';
      }
    } catch (_) {}
    return '-- MB';
  }

  Future<void> clearHistory() async {
    for (final v in downloadHistory) {
      final f = File(v.savePath);
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    await historyBox.clear();
    downloadHistory.clear();
  }

  Future<bool> _requestPermissions() async {
    bool isGranted = false;
    bool isPermanentlyDenied = false;

    if (Platform.isAndroid) {
      var vStatus = await Permission.videos.request();
      if (vStatus.isGranted) {
        isGranted = true;
      } else if (vStatus.isPermanentlyDenied) {
        isPermanentlyDenied = true;
      }
      if (!isGranted) {
        final photos = await Permission.photos.request();
        if (photos.isGranted) {
          isGranted = true;
        } else if (photos.isPermanentlyDenied) {
          isPermanentlyDenied = true;
        }
      }
      if (!isGranted) {
        var status = await Permission.storage.request();
        if (status.isGranted) {
          isGranted = true;
        } else if (status.isPermanentlyDenied) {
          isPermanentlyDenied = true;
        }
      }
    } else if (Platform.isIOS) {
      var status = await Permission.photosAddOnly.request();
      if (status.isGranted) {
        isGranted = true;
      } else if (status.isPermanentlyDenied) {
        isPermanentlyDenied = true;
      } else {
        var pStatus = await Permission.photos.request();
        if (pStatus.isGranted) {
          isGranted = true;
        } else if (pStatus.isPermanentlyDenied) {
          isPermanentlyDenied = true;
        }
      }
    }

    if (isGranted) return true;

    if (isPermanentlyDenied) {
      Get.defaultDialog(
        title: 'Permission Required',
        middleText:
            'Storage permission is required to save media. Please enable it in app settings.',
        textConfirm: 'Open Settings',
        textCancel: 'Cancel',
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          openAppSettings();
        },
      );
    } else {
      Get.snackbar(
        'Permission Denied',
        'Storage permission is required to save media.',
      );
    }
    return false;
  }
}
