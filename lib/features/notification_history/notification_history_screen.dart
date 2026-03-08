import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:installed_apps/installed_apps.dart';
import 'notification_history_controller.dart';
import 'notification_model.dart';

// In-memory icon cache to avoid repeated async calls
final Map<String, Uint8List?> _iconCache = {};

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final controller = Get.find<NotificationHistoryController>();
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        controller.updateSearch('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Advanced History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ).animate().fade(duration: 600.ms).slideY(begin: -0.5, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.titleLarge?.color),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.filter, size: 16),
            onPressed: () => _showFilterBottomSheet(context),
          ),
          IconButton(
            icon: FaIcon(
              _showSearch ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass,
              size: 16,
            ),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Option to clear history
               _showMenu(context);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Animated search bar
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _showSearch
                    ? Padding(
                        key: const ValueKey('searchBar'),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: controller.updateSearch,
                          decoration: InputDecoration(
                            hintText: 'Search notifications...',
                            hintStyle: const TextStyle(fontSize: 14),
                            prefixIcon: Icon(CupertinoIcons.search),
                            suffixIcon: IconButton(
                              icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                              onPressed: () {
                                _searchController.clear();
                                controller.updateSearch('');
                              },
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('noSearch')),
              ),
              Expanded(child: _buildListSection(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                title: const Text('Clear All Notifications', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Get.back();
                  _confirmClear();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.white),
                title: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Get.back();
                  _confirmClear();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmClear() {
    Get.defaultDialog(
      title: 'Clear History?',
      middleText: 'This will delete all saved notifications permanentely.',
      textConfirm: 'Clear',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      onConfirm: () {
        controller.clearHistory();
        Get.back();
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea( 
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.close, size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            'FILTERS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          controller.resetFilters();
                          setModalState(() {});
                          Get.back();
                        },
                        child: const Text(
                          'RESET',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SORT BY',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FilterChip(
                        label: 'New First',
                        isSelected: controller.sortOrder.value == 'New First',
                        onTap: () {
                          controller.updateSortOrder('New First');
                          setModalState(() {});
                        },
                      ),
                      _FilterChip(
                        label: 'Old First',
                        isSelected: controller.sortOrder.value == 'Old First',
                        onTap: () {
                          controller.updateSortOrder('Old First');
                          setModalState(() {});
                        },
                      ),
                      _FilterChip(
                        label: 'A - Z',
                        isSelected: controller.sortOrder.value == 'A-Z',
                        onTap: () {
                          controller.updateSortOrder('A-Z');
                          setModalState(() {});
                        },
                      ),
                      _FilterChip(
                        label: 'Z - A',
                        isSelected: controller.sortOrder.value == 'Z-A',
                        onTap: () {
                          controller.updateSortOrder('Z-A');
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Text(
                        'TIME',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Pro Version Only',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FilterChip(label: 'Today', isSelected: false, isLocked: true),
                      _FilterChip(label: 'Yesterday', isSelected: false, isLocked: true),
                      _FilterChip(label: 'This Week', isSelected: false, isLocked: true),
                      _FilterChip(label: 'This Month', isSelected: false, isLocked: true),
                      _FilterChip(label: 'Custom', isSelected: false, isLocked: true),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const Text(
                        'EXPORT',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Pro Version Only',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FilterChip(label: 'Excel', isSelected: false, isLocked: true),
                      _FilterChip(label: 'Text File', isSelected: false, isLocked: true),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[400],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {},
                          child: const Text('GET PRO VERSION', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00ACC1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () => Get.back(),
                          child: const Text('APPLY FILTERS', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildListSection(BuildContext context) {
    return Obx(() {
      if (controller.groupedNotifications.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_off, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('No notifications found', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ).animate().fade(duration: 600.ms);
      }
      
      final appKeys = controller.groupedNotifications.keys.toList();

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: appKeys.length,
        itemBuilder: (context, index) {
          final packageName = appKeys[index];
          final appNotifs = controller.groupedNotifications[packageName]!;
          final latestNotif = appNotifs.first; // Notifications are prepended, so first is latest
          final badgeCount = appNotifs.length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: InkWell(
                onTap: () {
                  Get.to(() => AppNotificationsScreen(
                    packageName: packageName, 
                    appName: _getAppName(packageName), 
                    appColor: _getAppColor(packageName)
                  ));
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                       Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _AppIcon(packageName: packageName, size: 56, fallbackLabel: _getAppName(packageName)[0].toUpperCase(), fallbackColor: _getAppColor(packageName)),
                          if (badgeCount > 0)
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange]),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                                ),
                                child: Text(
                                  badgeCount > 99 ? '99+' : badgeCount.toString(), 
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _getAppName(packageName), 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Text(
                                  DateFormat('hh:mm a').format(latestNotif.timestamp), 
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              latestNotif.title.isNotEmpty
                                  ? '${latestNotif.title}: ${latestNotif.text}'
                                  : latestNotif.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).animate().fade(duration: 500.ms, delay: (50 * index).ms).slideX(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOut);
        },
      );
    });
  }

  String _getAppName(String packageName) {
    if (packageName.contains('facebook.orca')) return 'Messenger';
    if (packageName.contains('whatsapp')) return 'WhatsApp';
    if (packageName.contains('facebook.katana')) return 'Facebook';
    if (packageName.contains('truecaller')) return 'Truecaller';
    if (packageName.contains('android.mms')) return 'Messages';
    if (packageName.contains('microsoft.teams')) return 'Teams';
    if (packageName.contains('android.dialer')) return 'Phone';
    if (packageName.contains('linkedin')) return 'LinkedIn';
    if (packageName.contains('instagram')) return 'Instagram';
    if (packageName.contains('telegram')) return 'Telegram';
    if (packageName.contains('snapchat')) return 'Snapchat';
    if (packageName.contains('twitter') || packageName.contains('x.com')) return 'X (Twitter)';
    if (packageName.contains('gmail')) return 'Gmail';
    if (packageName.contains('chrome')) return 'Chrome';
    if (packageName.contains('tiktok')) return 'TikTok';
    if (packageName.contains('spotify')) return 'Spotify';
    final parts = packageName.split('.');
    return parts.last.capitalizeFirst ?? packageName;
  }


  Color _getAppColor(String packageName) {
    if (packageName.contains('orca')) return Colors.blueAccent;
    if (packageName.contains('whatsapp')) return Colors.green;
    if (packageName.contains('youtube')) return Colors.redAccent;
    if (packageName.contains('teams')) return Colors.deepPurpleAccent;
    if (packageName.contains('truecaller')) return Colors.blue;
    if (packageName.contains('mms')) return Colors.lightBlue;
    return Colors.orangeAccent;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isLocked;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF00ACC1) 
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF00ACC1) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isLocked ? Colors.grey[400] : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class AppNotificationsScreen extends GetView<NotificationHistoryController> {
  final String packageName;
  final String appName;
  final Color appColor;

  const AppNotificationsScreen({
    super.key, 
    required this.packageName,
    required this.appName,
    required this.appColor,
  });

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final RxBool showSearch = false.obs;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(appName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Obx(() {
               final count = controller.groupedNotifications[packageName]?.length ?? 0;
               return Text('$count Messages', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color?.withValues(alpha: 0.7), fontSize: 13));
            }),
          ],
        ).animate().fade().slideX(begin: -0.1, end: 0, duration: 400.ms),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).textTheme.titleLarge?.color),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16), 
            onPressed: () => showSearch.value = !showSearch.value,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Obx(() => AnimatedSwitcher(
                duration: 300.ms,
                child: showSearch.value 
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: searchController,
                        onChanged: (val) => controller.updateSearch(val),
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search $appName...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white12,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              )),
              Expanded(
                child: Obx(() {
                  final senderGroups = controller.getNotificationsBySender(packageName);
                  final senders = senderGroups.keys.toList();

                  if (senders.isEmpty) {
                    return const Center(child: Text("No messages found"));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: senders.length,
                    itemBuilder: (context, index) {
                      final name = senders[index];
                      final messages = senderGroups[name]!;
                      final latest = messages.first;
                      final count = messages.length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          elevation: 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: InkWell(
                            onTap: () {
                              Get.to(() => SenderConversationScreen(
                                packageName: packageName,
                                appName: appName,
                                senderName: name,
                                messages: messages,
                                appColor: appColor,
                              ));
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Profile Photo or Icon
                                  if (latest.senderIcon != null)
                                    _SenderIcon(senderIcon: latest.senderIcon!, size: 52, appIcon: _AppIcon(
                                      packageName: packageName,
                                      size: 52,
                                      fallbackLabel: name[0].toUpperCase(),
                                      fallbackColor: appColor,
                                    ))
                                  else
                                    _AppIcon(
                                      packageName: packageName,
                                      size: 52,
                                      fallbackLabel: name[0].toUpperCase(),
                                      fallbackColor: appColor,
                                    ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            Text(
                                              DateFormat('hh:mm a').format(latest.timestamp), 
                                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                latest.text,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                              ),
                                            ),
                                            if (count > 0)
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00ACC1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  count.toString(),
                                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate().fade(duration: 400.ms, delay: (40 * index).ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Widget that loads the real launcher icon for a given package, with gradient fallback.
class _AppIcon extends StatelessWidget {
  final String packageName;
  final double size;
  final String fallbackLabel;
  final Color fallbackColor;

  const _AppIcon({
    required this.packageName,
    required this.size,
    required this.fallbackLabel,
    required this.fallbackColor,
  });

  Future<Uint8List?> _getIcon() async {
    if (_iconCache.containsKey(packageName)) {
      return _iconCache[packageName];
    }
    try {
      final app = await InstalledApps.getAppInfo(packageName);
      _iconCache[packageName] = app?.icon;
      return app?.icon;
    } catch (_) {
      _iconCache[packageName] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _getIcon(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipOval(
              child: Image.memory(
                snapshot.data!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        // Fallback gradient placeholder while loading or if icon unavailable
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [fallbackColor.withValues(alpha: 0.7), fallbackColor],
            ),
            boxShadow: [
              BoxShadow(color: fallbackColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
            ],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              fallbackLabel,
              style: TextStyle(color: Colors.white, fontSize: size * 0.45, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}

/// Widget that shows the sender's profile photo (from notification largeIcon/senderIcon).
/// Falls back to the given [appIcon] widget if the image fails to render.
class _SenderIcon extends StatelessWidget {
  final Uint8List senderIcon;
  final double size;
  final Widget appIcon;

  const _SenderIcon({
    required this.senderIcon,
    required this.size,
    required this.appIcon,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            senderIcon,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => appIcon,
          ),
        ),
      );
    } catch (_) {
      return appIcon;
    }
  }
}

/// Screen that shows the actual chat conversation for a specific sender (Image 2 style).
class SenderConversationScreen extends StatelessWidget {
  final String packageName;
  final String appName;
  final String senderName;
  final List<NotificationModel> messages;
  final Color appColor;

  const SenderConversationScreen({
    super.key,
    required this.packageName,
    required this.appName,
    required this.senderName,
    required this.messages,
    required this.appColor,
  });

  @override
  Widget build(BuildContext context) {
    // Sort messages by time (oldest first for chat flow)
    final sortedMessages = List<NotificationModel>.from(messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Group messages by date
    final Map<String, List<NotificationModel>> dateGroups = {};
    for (var m in sortedMessages) {
      final dateStr = DateFormat('MMMM dd, yyyy').format(m.timestamp);
      dateGroups.putIfAbsent(dateStr, () => []).add(m);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${messages.length} Messages', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          IconButton(icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: dateGroups.length,
          itemBuilder: (context, index) {
            final date = dateGroups.keys.elementAt(index);
            final dayMessages = dateGroups[date]!;
            
            return Column(
              children: [
                // Date Header
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      date,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                  ),
                ),
                // Messages for this day
                ...dayMessages.map((m) => _ChatBubble(
                  message: m,
                  appColor: appColor,
                  appName: appName,
                  packageName: packageName,
                )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final NotificationModel message;
  final Color appColor;
  final String appName;
  final String packageName;

  const _ChatBubble({
    required this.message,
    required this.appColor,
    required this.appName,
    required this.packageName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          if (message.senderIcon != null)
             _SenderIcon(senderIcon: message.senderIcon!, size: 36, appIcon: _AppIcon(
                packageName: packageName,
                size: 36,
                fallbackLabel: message.title.isNotEmpty ? message.title[0] : '?',
                fallbackColor: appColor,
             ))
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Center(child: Icon(Icons.person, color: Colors.grey[400], size: 24)),
            ),
          const SizedBox(width: 8),
          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[800] 
                        : const Color(0xFFF1F4F7),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title.isNotEmpty ? message.title : appName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.text,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          DateFormat('hh:mm a').format(message.timestamp),
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40), // Push bubble to left
        ],
      ),
    ).animate().fade().slideY(begin: 0.1, end: 0);
  }
}
