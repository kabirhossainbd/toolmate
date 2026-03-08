import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'user_profile_model.dart';
import '../video_downloader/video_model.dart';
import '../notification_history/notification_model.dart';

class UserProfileController extends GetxController {
  final _box = Hive.box<UserProfileModel>('user_profile');
  final ImagePicker _picker = ImagePicker();

  final Rx<UserProfileModel> profile = UserProfileModel().obs;
  final RxInt downloadCount = 0.obs;
  final RxInt notifCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadProfile();
    _initCounts();
  }

  void _initCounts() {
    final videoBox = Hive.box<VideoModel>('video_history');
    final notifBox = Hive.box<NotificationModel>('notifications');

    // Initial counts
    downloadCount.value = videoBox.length;
    notifCount.value = notifBox.length;

    // Listen for changes
    videoBox.watch().listen((_) => downloadCount.value = videoBox.length);
    notifBox.watch().listen((_) => notifCount.value = notifBox.length);
  }

  void _loadProfile() {
    if (_box.isNotEmpty) {
      profile.value = _box.getAt(0)!;
    } else {
      final defaultProfile = UserProfileModel(
        name: 'Your Name',
        bio: 'Write something about yourself...',
      );
      _box.add(defaultProfile);
      profile.value = defaultProfile;
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked != null) {
        final p = profile.value;
        p.imagePath = picked.path;
        await p.save();
        profile.refresh();
      }
    } catch (e) {
      Get.snackbar('Error', 'Could not pick image: $e');
    }
  }

  Future<void> updateName(String newName) async {
    final p = profile.value;
    p.name = newName.trim();
    await p.save();
    profile.refresh();
  }

  Future<void> updateBio(String newBio) async {
    final p = profile.value;
    p.bio = newBio.trim();
    await p.save();
    profile.refresh();
  }

  File? get profileImageFile {
    final path = profile.value.imagePath;
    if (path != null && File(path).existsSync()) {
      return File(path);
    }
    return null;
  }

  int get notificationCount => notifCount.value;
  int get downloadedVideosCount => downloadCount.value;

  void showImageSourceBottomSheet() {
    Get.bottomSheet(
      _ImageSourceSheet(controller: this),
      isScrollControlled: true,
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  final UserProfileController controller;
  const _ImageSourceSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose Photo',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: Colors.purpleAccent,
                onTap: () {
                  Get.back();
                  controller.pickImage(ImageSource.gallery);
                },
              ),
              _SourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: Colors.blueAccent,
                onTap: () {
                  Get.back();
                  controller.pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            ),
            child: Icon(icon, color: color, size: 34),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
