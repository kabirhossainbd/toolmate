import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import 'home_controller.dart';
import '../user_profile/user_profile_model.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Toolmate',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ).animate().fade(duration: 600.ms).slideY(begin: -0.5, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: controller.navigateToUserProfile,
              child: _ProfileAvatar(),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _HomeCard(
                  title: 'Storage Analyzer',
                  icon: FontAwesomeIcons.chartPie,
                  color: Colors.blueAccent,
                  onTap: controller.navigateToStorageAnalyzer,
                  index: 0,
                ),
                _HomeCard(
                  title: 'Video Downloader',
                  icon: FontAwesomeIcons.cloudArrowDown,
                  color: Colors.pinkAccent,
                  onTap: controller.navigateToVideoDownloader,
                  index: 1,
                ),
                _HomeCard(
                  title: 'Notification History',
                  icon: FontAwesomeIcons.solidBell,
                  color: Colors.orangeAccent,
                  onTap: controller.navigateToNotificationHistory,
                  index: 2,
                ),
                _HomeCard(
                  title: 'User Profile',
                  icon: FontAwesomeIcons.solidUser,
                  color: const Color(0xFF7B1FA2),
                  onTap: controller.navigateToUserProfile,
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    try {
      final box = Hive.box<UserProfileModel>('user_profile');
      if (box.isNotEmpty) {
        final profile = box.getAt(0)!;
        final imgPath = profile.imagePath;
        final hasImage = imgPath != null && File(imgPath).existsSync();
        final name = profile.name;
        final imgFile = hasImage ? File(imgPath) : null;

        return CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF1E88E5),
          backgroundImage: imgFile != null ? FileImage(imgFile) : null,
          child: !hasImage
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        );
      }
    } catch (_) {}

    return const CircleAvatar(
      radius: 18,
      backgroundColor: Color(0xFF1E88E5),
      child: Icon(Icons.person, color: Colors.white, size: 20),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int index;

  const _HomeCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.7),
                color,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, size: 36, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fade(duration: 600.ms, delay: (150 * index).ms)
      .scale(duration: 600.ms, delay: (150 * index).ms, curve: Curves.easeOutBack);
  }
}
