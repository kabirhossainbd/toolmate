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
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class VideoDownloaderController extends GetxController
    with GetSingleTickerProviderStateMixin {
  // Tab controller
  late TabController tabController;

  // Input
  final urlController = ''.obs;
  final textEditingController = TextEditingController();

  // State
  final Rx<VideoModel?> currentVideo = Rx<VideoModel?>(null);
  final isFetching = false.obs;
  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;

  // Hive storage
  late Box<VideoModel> historyBox;
  final RxList<VideoModel> downloadHistory = <VideoModel>[].obs;

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

  // ─── Clipboard paste ───────────────────────────────────────────────────────
  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      textEditingController.text = data.text!;
      urlController.value = data.text!;
    } else {
      Get.snackbar('Clipboard', 'No text found in clipboard');
    }
  }

  // ─── Fetch video info ───────────────────────────────────────────────────────
  Future<void> fetchVideoInfo(String url) async {
    final parsedUri = Uri.tryParse(url);
    if (url.isEmpty || parsedUri == null || !parsedUri.isAbsolute) {
      Get.snackbar('Error', 'Please enter a valid URL');
      return;
    }

    isFetching.value = true;
    currentVideo.value = null;

    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        var yt = YoutubeExplode();
        try {
          var video = await yt.videos.get(url);
          String thumbnailUrl = video.thumbnails.highResUrl;
          if (thumbnailUrl.isEmpty) thumbnailUrl = video.thumbnails.mediumResUrl;
          currentVideo.value = VideoModel(
            url: url,
            title: video.title,
            thumbnailUrl: thumbnailUrl,
            savePath: '',
            downloadDate: DateTime.now(),
          );
          // Switch to confirm download
        } catch (_) {
          Get.snackbar('Error', 'Failed to fetch YouTube video info.');
        } finally {
          yt.close();
        }
      } else {
        // Generic direct link — treat as downloadable
        final uri = Uri.parse(url);
        final fileName = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        currentVideo.value = VideoModel(
          url: url,
          title: fileName,
          thumbnailUrl: '',
          savePath: '',
          downloadDate: DateTime.now(),
        );
      }
    } catch (_) {
      Get.snackbar('Error', 'An unexpected error occurred.');
    } finally {
      isFetching.value = false;
    }
  }

  // ─── Download video ─────────────────────────────────────────────────────────
  Future<void> downloadVideo() async {
    if (currentVideo.value == null) return;
    if (!(await _requestPermissions())) return;

    isDownloading.value = true;
    downloadProgress.value = 0.0;

    try {
      String videoUrl = currentVideo.value!.url;

      if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
        var yt = YoutubeExplode();
        try {
          var manifest = await yt.videos.streamsClient.getManifest(videoUrl);
          var streamInfo = manifest.muxed.withHighestBitrate();
          videoUrl = streamInfo.url.toString();
        } catch (_) {
          Get.snackbar('Error', 'Failed to get YouTube video stream.');
          isDownloading.value = false;
          yt.close();
          return;
        } finally {
          yt.close();
        }
      }

      Directory tempDir = await getTemporaryDirectory();
      String fileName = '${currentVideo.value!.title.replaceAll(RegExp(r'[^\w]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      String savePath = '${tempDir.path}/$fileName';

      dio.Dio dlDio = dio.Dio();
      await dlDio.download(
        videoUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) downloadProgress.value = received / total;
        },
      );

      bool? saved = await GallerySaver.saveVideo(savePath, albumName: 'ToolMate');

      if (saved == true) {
        VideoModel completedVideo = VideoModel(
          url: currentVideo.value!.url,
          title: currentVideo.value!.title,
          thumbnailUrl: currentVideo.value!.thumbnailUrl,
          savePath: savePath,
          downloadDate: DateTime.now(),
        );
        await historyBox.add(completedVideo);
        _loadHistory();
        Get.snackbar('Success', 'Video saved to gallery!',
            backgroundColor: Colors.green, colorText: Colors.white);
        currentVideo.value = null;
        urlController.value = '';
        textEditingController.clear();
        // Switch to downloads tab
        tabController.animateTo(1);
      } else {
        Get.snackbar('Error', 'Failed to save video to gallery.');
      }
    } catch (e) {
      Get.log('Download error: $e');
      Get.snackbar('Error', 'Failed to download video.');
    } finally {
      isDownloading.value = false;
    }
  }

  // ─── Share video ────────────────────────────────────────────────────────────
  Future<void> shareVideo(VideoModel video) async {
    final file = File(video.savePath);
    if (file.existsSync()) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(video.savePath)], text: video.title),
      );
    } else {
      // Share only the URL if file missing
      await SharePlus.instance.share(
        ShareParams(text: '${video.title}\n${video.url}'),
      );
    }
  }

  // ─── Delete video ───────────────────────────────────────────────────────────
  Future<void> deleteVideo(VideoModel video) async {
    // Remove Hive record
    await video.delete();
    // Delete file from storage
    final file = File(video.savePath);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    _loadHistory();
    Get.snackbar('Deleted', 'Video removed successfully.');
  }

  // ─── Copy link ──────────────────────────────────────────────────────────────
  void copyLink(VideoModel video) {
    Clipboard.setData(ClipboardData(text: video.url));
    Get.snackbar('Copied', 'Link copied to clipboard');
  }

  // ─── Play video ─────────────────────────────────────────────────────────────
  void playVideo(VideoModel video) {
    final file = File(video.savePath);
    if (file.existsSync()) {
      Get.to(() => VideoPlayerScreen(video: video));
    } else {
      Get.snackbar('Not found', 'Video file not found on device.');
    }
  }

  // ─── Get file size ──────────────────────────────────────────────────────────
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

  // ─── Clear all history ──────────────────────────────────────────────────────
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

  // ─── Permissions ────────────────────────────────────────────────────────────
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
            'Storage permission is required to save videos. Please enable it in app settings.',
        textConfirm: 'Open Settings',
        textCancel: 'Cancel',
        confirmTextColor: Colors.white,
        onConfirm: () {
          Get.back();
          openAppSettings();
        },
      );
    } else {
      Get.snackbar('Permission Denied',
          'Storage permission is required to save videos.');
    }
    return false;
  }
}
