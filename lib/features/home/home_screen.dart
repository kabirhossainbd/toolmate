import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive/hive.dart';
import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'home_controller.dart';
import '../user_profile/user_profile_model.dart';
import '../notification_history/notification_model.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = <FeatureAccent>[
      FeatureAccent(
        title: 'Storage Analyzer',
        subtitle: 'Clean & free space',
        icon: FontAwesomeIcons.chartPie,
        color: AppUi.brandBlue,
        onTap: controller.navigateToStorageAnalyzer,
      ),
      FeatureAccent(
        title: 'Video Downloader',
        subtitle: 'Save videos offline',
        icon: FontAwesomeIcons.cloudArrowDown,
        color: AppUi.brandPink,
        onTap: controller.navigateToVideoDownloader,
      ),
      FeatureAccent(
        title: 'Notifications',
        subtitle: 'Never miss a chat',
        icon: FontAwesomeIcons.solidBell,
        color: AppUi.brandOrange,
        onTap: controller.navigateToNotificationHistory,
      ),
      FeatureAccent(
        title: 'Profile',
        subtitle: 'Customize your app',
        icon: FontAwesomeIcons.solidUser,
        color: AppUi.brandPurple,
        onTap: controller.navigateToUserProfile,
      ),
    ];

    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        title: Text(
          'Toolmate',
          style: openSansExtraBold.copyWith(
            fontSize: 26,
            letterSpacing: 0.4,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        )
            .animate()
            .fade(duration: 450.ms)
            .slideY(begin: -0.25, end: 0, curve: Curves.easeOutCubic),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: controller.navigateToUserProfile,
              child: const _ProfileAvatar(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _HeroBanner(
                  onProfileTap: controller.navigateToUserProfile,
                )
                    .animate()
                    .fade(duration: 400.ms)
                    .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final feature = features[index];
                    return _HomeCard(
                      feature: feature,
                      index: index,
                    );
                  },
                  childCount: features.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final VoidCallback onProfileTap;

  const _HeroBanner({required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppUi.brandHero,
        borderRadius: BorderRadius.circular(AppUi.radiusLg),
        boxShadow: AppUi.softGlow(AppUi.brandDeep, opacity: 0.35),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -24,
            child: Icon(
              FontAwesomeIcons.screwdriverWrench,
              size: 110,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Smart toolkit',
                      style: openSansSemiBold.copyWith(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'All your utilities\nin one place',
                style: openSansExtraBold.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Clean storage, save videos, and keep notification history.',
                style: openSansRegular.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: onProfileTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Open profile',
                        style: openSansSemiBold.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    UserProfileModel? profile;
    try {
      final box = Hive.box<UserProfileModel>('user_profile');
      if (box.isNotEmpty) profile = box.getAt(0);
    } catch (_) {}

    final imgPath = profile?.imagePath;
    final hasImage = imgPath != null && File(imgPath).existsSync();
    final name = profile?.name ?? '';

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppUi.brandHero,
        boxShadow: AppUi.softGlow(AppUi.brandBlue, opacity: 0.35),
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppUi.brandBlue,
        backgroundImage: hasImage ? FileImage(File(imgPath)) : null,
        child: !hasImage
            ? Text(
                safeInitial(name, 'U'),
                style: openSansBold.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                ),
              )
            : null,
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final FeatureAccent feature;
  final int index;

  const _HomeCard({
    required this.feature,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(AppUi.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUi.radiusLg),
            gradient: AppUi.accentGradient(feature.color),
            boxShadow: AppUi.softGlow(feature.color),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Center(
                    child: FaIcon(feature.icon, size: 22, color: Colors.white),
                  ),
                ),
                const Spacer(),
                Text(
                  feature.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: openSansBold.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: openSansRegular.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fade(duration: 380.ms, delay: (70 * index).ms)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 380.ms,
          delay: (70 * index).ms,
          curve: Curves.easeOutCubic,
        );
  }
}
