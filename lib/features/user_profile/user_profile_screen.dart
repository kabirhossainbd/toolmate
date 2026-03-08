import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'user_profile_controller.dart';

class UserProfileScreen extends GetView<UserProfileController> {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Obx(() {
        final profile = controller.profile.value;
        final imgFile = controller.profileImageFile;

        return CustomScrollView(
          slivers: [
            // --- Gradient SliverAppBar ---
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: const Color(0xFF1565C0),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Get.back(),
              ),
              title: const Text(
                'My Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1565C0),
                            Color(0xFF7B1FA2),
                            Color(0xFF00838F),
                          ],
                        ),
                      ),
                    ),
                    // Decorative circles
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    // Profile avatar + name in flexible space
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: controller.showImageSourceBottomSheet,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF64B5F6),
                                        Color(0xFF9575CD)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: imgFile != null
                                      ? FileImage(imgFile)
                                      : null,
                                  child: imgFile == null
                                      ? Text(
                                          profile.name.isNotEmpty
                                              ? profile.name[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                // Edit badge
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1E88E5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().scale(
                                duration: 500.ms,
                                curve: Curves.easeOutBack,
                              ),
                          const SizedBox(height: 10),
                          Text(
                            profile.name.isEmpty ? 'Your Name' : profile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ).animate().fade(duration: 400.ms, delay: 200.ms),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Body Content ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 70),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row
                    _StatsRow(
                      notificationCount: controller.notificationCount,
                      downloadCount: controller.downloadedVideosCount,
                    ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(
                          begin: 0.3,
                          end: 0,
                          duration: 400.ms,
                          delay: 100.ms,
                        ),

                    const SizedBox(height: 24),

                    // Profile Info Card
                    _SectionLabel(label: 'Personal Info'),
                    const SizedBox(height: 10),
                    _ProfileInfoCard(
                      name: profile.name,
                      bio: profile.bio,
                      isDark: isDark,
                      onEditName: () => _showEditDialog(
                        context: context,
                        title: 'Edit Name',
                        initialValue: profile.name,
                        hint: 'Enter your name',
                        onSave: controller.updateName,
                      ),
                      onEditBio: () => _showEditDialog(
                        context: context,
                        title: 'Edit Bio',
                        initialValue: profile.bio,
                        hint: 'Write something about yourself',
                        maxLines: 3,
                        onSave: controller.updateBio,
                      ),
                    ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(
                          begin: 0.3,
                          end: 0,
                          duration: 400.ms,
                          delay: 200.ms,
                        ),

                    const SizedBox(height: 24),

                    // Appearance Section
                    _SectionLabel(label: 'Appearance'),
                    const SizedBox(height: 10),
                    _ThemeToggleCard(isDark: isDark)
                        .animate()
                        .fade(duration: 400.ms, delay: 300.ms)
                        .slideY(
                          begin: 0.3,
                          end: 0,
                          duration: 400.ms,
                          delay: 300.ms,
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showEditDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required String hint,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
  }) {
    final textController = TextEditingController(text: initialValue);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Get.dialog(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: textController,
          maxLines: maxLines,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.grey.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[500])),
          ),
          FilledButton(
            onPressed: () {
              onSave(textController.text);
              Get.back();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Sub-Widgets
// ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Color(0xFF1E88E5),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int notificationCount;
  final int downloadCount;

  const _StatsRow({
    required this.notificationCount,
    required this.downloadCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            value: notificationCount.toString(),
            color: Colors.orangeAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.cloud_download_rounded,
            label: 'Downloads',
            value: downloadCount.toString(),
            color: Colors.pinkAccent,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StatCard(
            icon: Icons.storage_rounded,
            label: 'Analyzer',
            value: '✓',
            color: Colors.blueAccent,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final String name;
  final String bio;
  final bool isDark;
  final VoidCallback onEditName;
  final VoidCallback onEditBio;

  const _ProfileInfoCard({
    required this.name,
    required this.bio,
    required this.isDark,
    required this.onEditName,
    required this.onEditBio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Name',
            value: name.isEmpty ? 'Tap to set name' : name,
            iconColor: const Color(0xFF1E88E5),
            isDark: isDark,
            onTap: onEditName,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _InfoRow(
            icon: Icons.edit_note_rounded,
            label: 'Bio',
            value: bio.isEmpty ? 'Tap to add a bio' : bio,
            iconColor: const Color(0xFF7B1FA2),
            isDark: isDark,
            onTap: onEditBio,
            isMultiLine: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onTap;
  final bool isMultiLine;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.isDark,
    required this.onTap,
    this.isMultiLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: isMultiLine ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_rounded,
              size: 16,
              color: Colors.grey.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleCard extends StatelessWidget {
  final bool isDark;
  const _ThemeToggleCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: const Color(0xFF7B1FA2),
            size: 20,
          ),
        ),
        title: Text(
          isDark ? 'Dark Mode' : 'Light Mode',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          'Tap to switch theme',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: Switch(
          value: isDark,
          onChanged: (_) {
            Get.changeThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
          },
          activeThumbColor: const Color(0xFF7B1FA2),
        ),
      ),
    );
  }
}
