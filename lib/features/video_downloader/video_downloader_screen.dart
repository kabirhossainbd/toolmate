import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'video_downloader_controller.dart';
import 'video_model.dart';

// ─── Brand colors (constant) ──────────────────────────────────────────────────
const _kBlue = Color(0xFF1565C0);

class VideoDownloaderScreen extends GetView<VideoDownloaderController> {
  const VideoDownloaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: controller.tabController,
              children: [
                _InsertLinkTab(controller: controller),
                _DownloadedTab(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = Theme.of(context).appBarTheme.backgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final titleColor = isDark ? Colors.white : Colors.black87;

    return AppBar(
      backgroundColor: appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 0,
      leading: SizedBox(),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: iconColor),
            onPressed: () => Get.back(),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.download_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Video Downloader',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.diamond, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Text('Sale 60%',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dividerColor =
        isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: tabBg,
        border: Border(
          bottom: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      child: TabBar(
        controller: controller.tabController,
        labelColor: _kBlue,
        unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w400, fontSize: 15),
        indicatorColor: _kBlue,
        indicatorWeight: 2.5,
        tabs: const [
          Tab(text: 'Insert link'),
          Tab(text: 'Download'),
        ],
      ),
    );
  }
}

// ─── Insert Link Tab ──────────────────────────────────────────────────────────
class _InsertLinkTab extends StatelessWidget {
  final VideoDownloaderController controller;
  const _InsertLinkTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerBg = isDark ? const Color(0xFF121212) : Colors.grey.shade100;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── URL input section ───────────────────────────────────────────────
          Container(
            color: sectionBg,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                // TextField + Paste button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.textEditingController,
                        onChanged: (val) =>
                            controller.urlController.value = val,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Paste Social media video link...',
                          hintStyle:
                              TextStyle(color: hintColor, fontSize: 14),
                          filled: true,
                          fillColor: fieldFill,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: _kBlue, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: controller.pasteFromClipboard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: _kBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Paste',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Download button
                Obx(() => GestureDetector(
                      onTap: (controller.urlController.value.isEmpty ||
                              controller.isFetching.value ||
                              controller.isDownloading.value)
                          ? null
                          : () => controller
                              .fetchVideoInfo(controller.urlController.value),
                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: (controller.urlController.value.isEmpty &&
                                  !controller.isFetching.value)
                              ? (isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300)
                              : _kBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (controller.isFetching.value ||
                                controller.isDownloading.value)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            else
                              const Icon(Icons.download_rounded,
                                  color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              controller.isFetching.value
                                  ? 'Fetching...'
                                  : controller.isDownloading.value
                                      ? 'Downloading...'
                                      : 'Download',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),

                // Download progress
                Obx(() {
                  if (!controller.isDownloading.value) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: controller.downloadProgress.value,
                            backgroundColor: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade200,
                            color: _kBlue,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${(controller.downloadProgress.value * 100).toStringAsFixed(0)}% Downloaded',
                          style:
                              TextStyle(color: subtitleColor, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Video found preview card ────────────────────────────────────────
          Obx(() {
            if (controller.currentVideo.value == null) {
              return const SizedBox.shrink();
            }
            final video = controller.currentVideo.value!;
            final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
            final cancelBorder =
                isDark ? Colors.white24 : Colors.grey.shade300;
            final cancelText =
                isDark ? Colors.grey.shade300 : Colors.black54;

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(
                          alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: video.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            video.thumbnailUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, _) =>
                                _videoPlaceholder(),
                          )
                        : _videoPlaceholder(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color:
                                    isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text(Uri.parse(video.url).host,
                            style: TextStyle(
                                color: subtitleColor, fontSize: 12)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    controller.currentVideo.value = null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: cancelBorder),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text('Cancel',
                                        style: TextStyle(
                                            color: cancelText,
                                            fontWeight:
                                                FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: controller.downloadVideo,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _kBlue,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text('Download to Gallery',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          // ── Divider ─────────────────────────────────────────────────────────
          Container(height: 8, color: dividerBg),

          // ── How to Download guide ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to Download',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 16),
                _HowToStep(
                  number: 1,
                  text: 'Open Social media and Copy link video',
                ),
                const SizedBox(height: 12),
                _HowToStep(
                  number: 2,
                  text: 'Open "Video Downloader" and Paste link video',
                ),
                const SizedBox(height: 12),
                _HowToStep(
                  number: 3,
                  text: 'Press Download and Choose the type you want',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoPlaceholder() {
    return Container(
      height: 180,
      color: Colors.grey.shade800,
      child: const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: Colors.white70, size: 60),
      ),
    );
  }
}

// ─── Downloaded Videos Tab ───────────────────────────────────────────────────
class _DownloadedTab extends StatelessWidget {
  final VideoDownloaderController controller;
  const _DownloadedTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyIconColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final emptyTextColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    final emptySubColor =
        isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final countColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Obx(() {
      if (controller.downloadHistory.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined,
                  size: 72, color: emptyIconColor),
              const SizedBox(height: 16),
              Text('No downloaded videos yet',
                  style: TextStyle(
                      color: emptyTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text('Go to Insert link tab to download a video',
                  style: TextStyle(color: emptySubColor, fontSize: 13)),
            ],
          ),
        );
      }

      return Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${controller.downloadHistory.length} video(s)',
                  style: TextStyle(color: countColor, fontSize: 13),
                ),
                GestureDetector(
                  onTap: () {
                    Get.defaultDialog(
                      title: 'Clear All',
                      middleText: 'Remove all downloaded videos?',
                      textConfirm: 'Clear All',
                      textCancel: 'Cancel',
                      confirmTextColor: Colors.white,
                      buttonColor: Colors.red,
                      onConfirm: () {
                        controller.clearHistory();
                        Get.back();
                      },
                    );
                  },
                  child: const Text('Clear all',
                      style: TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: controller.downloadHistory.length,
              itemBuilder: (context, index) {
                final video = controller.downloadHistory[index];
                return _VideoListItem(
                  video: video,
                  controller: controller,
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

// ─── Video List Item ─────────────────────────────────────────────────────────
class _VideoListItem extends StatelessWidget {
  final VideoModel video;
  final VideoDownloaderController controller;

  const _VideoListItem({required this.video, required this.controller});

  void _showOptionsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final handleColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: sheetBg,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87),
              ),
            ),
            const Divider(),
            _BottomSheetOption(
              icon: Icons.copy_rounded,
              label: 'Copy Link',
              onTap: () {
                Get.back();
                controller.copyLink(video);
              },
            ),
            _BottomSheetOption(
              icon: Icons.play_circle_outline_rounded,
              label: 'Play now',
              onTap: () {
                Get.back();
                controller.playVideo(video);
              },
            ),
            _BottomSheetOption(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: () {
                Get.back();
                controller.shareVideo(video);
              },
            ),
            _BottomSheetOption(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: Colors.red,
              onTap: () {
                Get.back();
                Get.defaultDialog(
                  title: 'Delete Video',
                  middleText: 'Delete "${video.title}"?',
                  textConfirm: 'Delete',
                  textCancel: 'Cancel',
                  confirmTextColor: Colors.white,
                  buttonColor: Colors.red,
                  onConfirm: () {
                    Get.back();
                    controller.deleteVideo(video);
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final cardBorder = isDark ? Colors.white10 : Colors.grey.shade200;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final secondaryColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final dividerColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final iconMenuColor = isDark ? Colors.grey.shade400 : Colors.black54;

    final fileSize = controller.getFileSize(video.savePath);
    final fileName = video.title.length > 30
        ? '${video.title.substring(0, 30)}...'
        : video.title;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail / play icon
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                video.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        video.thumbnailUrl,
                        width: 72,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, _) => _thumbPlaceholder(),
                      )
                    : _thumbPlaceholder(),
                Container(
                  width: 72,
                  height: 52,
                  color: Colors.black26,
                  child: const Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Title + size + actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: titleColor),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showOptionsBottomSheet(context),
                      child: Icon(Icons.more_vert,
                          color: iconMenuColor, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      fileSize,
                      style:
                          TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                    const Spacer(),
                    // Share
                    GestureDetector(
                      onTap: () => controller.shareVideo(video),
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded,
                              size: 15, color: secondaryColor),
                          const SizedBox(width: 3),
                          Text('Share',
                              style: TextStyle(
                                  color: secondaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      height: 14,
                      width: 1,
                      color: dividerColor,
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    // Delete
                    GestureDetector(
                      onTap: () {
                        Get.defaultDialog(
                          title: 'Delete',
                          middleText: 'Delete this video?',
                          textConfirm: 'Delete',
                          textCancel: 'Cancel',
                          confirmTextColor: Colors.white,
                          buttonColor: Colors.red,
                          onConfirm: () {
                            Get.back();
                            controller.deleteVideo(video);
                          },
                        );
                      },
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 15, color: Colors.red.shade400),
                          const SizedBox(width: 3),
                          Text('Delete',
                              style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      width: 72,
      height: 52,
      color: Colors.grey.shade800,
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────
class _HowToStep extends StatelessWidget {
  final int number;
  final String text;
  const _HowToStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleColor =
        isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final numColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: circleColor, width: 1.5),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                  color: numColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = color ??
        (isDark ? Colors.grey.shade200 : Colors.black87);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: defaultColor, size: 22),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    color: defaultColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
