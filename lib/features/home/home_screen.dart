import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../../core/app_ui.dart';
import '../../core/constants/app_constants.dart';
import '../../core/features/feature_item.dart';
import '../../core/style.dart';
import '../../routes/app_routes.dart';
import '../notification_history/notification_model.dart';
import '../user_profile/user_profile_model.dart';
import 'home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          cacheExtent: 200,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'app_name'.tr,
                            style: openSansExtraBold.copyWith(
                              fontSize: 26,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'tagline'.tr,
                            style: openSansRegular.copyWith(
                              fontSize: 13,
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Profile',
                      onPressed: () => Get.toNamed(Routes.userProfile),
                      icon: const _ProfileAvatar(),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: const _WelcomeCard(),
              ),
            ),
            for (final category in controller.categories) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Text(
                    category.tr,
                    style: openSansBold.copyWith(
                      fontSize: 15,
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
              ...controller.featuresFor(category).map(
                    (f) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _FeatureRow(
                          feature: f,
                          onTap: () => controller.openFeature(f),
                        ),
                      ),
                    ),
                  ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppUi.brandHero,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'welcome_title'.tr,
            style: openSansBold.copyWith(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'welcome_body'.tr,
            style: openSansRegular.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 180.ms);
  }
}

class _FeatureRow extends StatelessWidget {
  final FeatureItem feature;
  final VoidCallback onTap;

  const _FeatureRow({required this.feature, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: FaIcon(feature.icon, size: 18, color: feature.color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title.tr,
                      style: openSansSemiBold.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feature.subtitle.tr,
                      style: openSansRegular.copyWith(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
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
      final box = Hive.box<UserProfileModel>(AppConstants.boxUserProfile);
      if (box.isNotEmpty) profile = box.getAt(0);
    } catch (_) {}

    final imgPath = profile?.imagePath;
    final hasImage = imgPath != null && File(imgPath).existsSync();
    final name = profile?.name ?? '';

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppUi.brandBlue,
      backgroundImage: hasImage ? FileImage(File(imgPath)) : null,
      child: !hasImage
          ? Text(
              safeInitial(name, 'U'),
              style: openSansBold.copyWith(color: Colors.white, fontSize: 13),
            )
          : null,
    );
  }
}
