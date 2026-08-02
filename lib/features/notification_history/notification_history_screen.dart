import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:installed_apps/installed_apps.dart';
import '../../core/app_ui.dart';
import '../../core/style.dart';
import '../../routes/app_routes.dart';
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
  late final NotificationHistoryController controller;
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<NotificationHistoryController>()
        ? Get.find<NotificationHistoryController>()
        : Get.put(NotificationHistoryController());
  }

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
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Notification History',
          style: openSansBold.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.filter, size: 16),
            tooltip: 'Filter',
            onPressed: () => _showFilterBottomSheet(context),
          ),
          IconButton(
            icon: FaIcon(
              _showSearch ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass,
              size: 16,
            ),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: SafeArea(
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
                            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppUi.radiusMd),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('noSearch')),
              ),
              Obx(() {
                final hasActive = controller.timeFilter.value != 'All' ||
                    controller.selectedApp.value != 'All' ||
                    controller.unreadOnly.value ||
                    controller.sortOrder.value != 'New First';
                if (!hasActive) return const SizedBox.shrink();
                return SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (controller.unreadOnly.value)
                        _ActiveFilterPill(
                          label: 'Unread',
                          onClear: () => controller.toggleUnreadOnly(false),
                        ),
                      if (controller.timeFilter.value != 'All')
                        _ActiveFilterPill(
                          label: controller.timeFilter.value,
                          onClear: () => controller.updateTimeFilter('All'),
                        ),
                      if (controller.selectedApp.value != 'All')
                        _ActiveFilterPill(
                          label: _getAppName(controller.selectedApp.value),
                          onClear: () => controller.updateAppFilter('All'),
                        ),
                      if (controller.sortOrder.value != 'New First')
                        _ActiveFilterPill(
                          label: controller.sortOrder.value,
                          onClear: () =>
                              controller.updateSortOrder('New First'),
                        ),
                      TextButton(
                        onPressed: controller.resetFilters,
                        child: const Text('Clear all',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
              Expanded(child: _buildListSection(context)),
            ],
          ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.ios_share_rounded,
                    color: isDark ? Colors.white70 : Colors.black87),
                title: const Text('Export as Text'),
                onTap: () {
                  Get.back();
                  controller.exportNotifications(format: 'text');
                },
              ),
              ListTile(
                leading: Icon(Icons.table_chart_outlined,
                    color: isDark ? Colors.white70 : Colors.black87),
                title: const Text('Export as CSV / Excel'),
                onTap: () {
                  Get.back();
                  controller.exportNotifications(format: 'csv');
                },
              ),
              ListTile(
                leading: const Icon(Icons.mark_email_read_outlined,
                    color: Color(0xFF00ACC1)),
                title: const Text('Mark all as read'),
                onTap: () async {
                  Get.back();
                  await controller.markAllRead();
                  Get.snackbar('Done', 'All notifications marked as read');
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_sweep, color: Colors.redAccent),
                title: const Text('Clear All Notifications',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Get.back();
                  _confirmClear();
                },
              ),
              ListTile(
                leading: Icon(Icons.close,
                    color: isDark ? Colors.white54 : Colors.black54),
                title: const Text('Cancel'),
                onTap: () => Get.back(),
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
      middleText: 'This will delete all saved notifications permanently.',
      textConfirm: 'Clear',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      onConfirm: () {
        controller.clearHistory();
        Get.back();
      },
    );
  }

  Future<void> _pickCustomRange(StateSetter setModalState) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: controller.customStart.value ??
            now.subtract(const Duration(days: 7)),
        end: controller.customEnd.value ?? now,
      ),
    );
    if (range != null) {
      controller.updateCustomRange(range.start, range.end);
      setModalState(() {});
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Get.bottomSheet(
      SafeArea(
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Get.back(),
                      ),
                      const Text(
                        'FILTERS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          controller.resetFilters();
                          setModalState(() {});
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
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Unread only',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            value: controller.unreadOnly.value,
                            activeThumbColor: const Color(0xFF00ACC1),
                            onChanged: (v) {
                              controller.toggleUnreadOnly(v);
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'SORT BY',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final label in [
                                'New First',
                                'Old First',
                                'A-Z',
                                'Z-A'
                              ])
                                _FilterChip(
                                  label: label == 'A-Z'
                                      ? 'A - Z'
                                      : label == 'Z-A'
                                          ? 'Z - A'
                                          : label,
                                  isSelected:
                                      controller.sortOrder.value == label,
                                  onTap: () {
                                    controller.updateSortOrder(label);
                                    setModalState(() {});
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'TIME',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final label in [
                                'All',
                                'Today',
                                'Yesterday',
                                'This Week',
                                'This Month',
                                'Custom',
                              ])
                                _FilterChip(
                                  label: label,
                                  isSelected:
                                      controller.timeFilter.value == label,
                                  onTap: () async {
                                    if (label == 'Custom') {
                                      await _pickCustomRange(setModalState);
                                    } else {
                                      controller.updateTimeFilter(label);
                                      setModalState(() {});
                                    }
                                  },
                                ),
                            ],
                          ),
                          if (controller.timeFilter.value == 'Custom' &&
                              controller.customStart.value != null &&
                              controller.customEnd.value != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                '${DateFormat('MMM dd, yyyy').format(controller.customStart.value!)} → ${DateFormat('MMM dd, yyyy').format(controller.customEnd.value!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'APP',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Obx(() {
                            final apps = controller.uniqueApps;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final app in apps.take(20))
                                  _FilterChip(
                                    label: app == 'All'
                                        ? 'All Apps'
                                        : _getAppName(app),
                                    isSelected:
                                        controller.selectedApp.value == app,
                                    onTap: () {
                                      controller.updateAppFilter(app);
                                      setModalState(() {});
                                    },
                                  ),
                              ],
                            );
                          }),
                          const SizedBox(height: 24),
                          const Text(
                            'EXPORT',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _FilterChip(
                                label: 'CSV / Excel',
                                isSelected: false,
                                onTap: () {
                                  Get.back();
                                  controller.exportNotifications(
                                      format: 'csv');
                                },
                              ),
                              _FilterChip(
                                label: 'Text File',
                                isSelected: false,
                                onTap: () {
                                  Get.back();
                                  controller.exportNotifications(
                                      format: 'text');
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ACC1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('APPLY FILTERS',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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
      controller.readStateVersion.value;
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
        );
      }
      
      final appKeys = controller.groupedNotifications.keys.toList();

      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: appKeys.length,
        itemBuilder: (context, index) {
          final packageName = appKeys[index];
          final appNotifs = controller.groupedNotifications[packageName]!;
          final latestNotif = appNotifs.first;
          final unreadCount = controller.unreadCountForApp(packageName);
          final totalCount = appNotifs.length;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: InkWell(
                onTap: () {
                  Get.toNamed(
                    Routes.notificationApp,
                    arguments: {
                      'packageName': packageName,
                      'appName': _getAppName(packageName),
                      'appColor': _getAppColor(packageName),
                    },
                  );
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
                          _AppIcon(packageName: packageName, size: 56, fallbackLabel: safeInitial(_getAppName(packageName)), fallbackColor: _getAppColor(packageName)),
                          if (unreadCount > 0)
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
                                  unreadCount > 99 ? '99+' : unreadCount.toString(), 
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
                                style: TextStyle(
                                  fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.bold,
                                  fontSize: 14,
                                ),
                                  ),
                                ),
                                Text(
                                  DateFormat('hh:mm a').format(latestNotif.timestamp), 
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                    color: unreadCount > 0
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
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
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: unreadCount > 0 ? 0.85 : 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              unreadCount > 0
                                  ? '$unreadCount unread · $totalCount total'
                                  : '$totalCount messages',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
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
    if (packageName.contains('tiktok') ||
        packageName.contains('musically') ||
        packageName.contains('aweme')) return 'TikTok';
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

class _ActiveFilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _ActiveFilterPill({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: onClear,
        deleteIconColor: const Color(0xFF00ACC1),
        backgroundColor: const Color(0xFF00ACC1).withValues(alpha: 0.12),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedText = isDark ? Colors.white70 : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00ACC1)
              : Colors.grey.withValues(alpha: isDark ? 0.2 : 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF00ACC1) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : unselectedText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class AppNotificationsScreen extends StatefulWidget {
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
  State<AppNotificationsScreen> createState() => _AppNotificationsScreenState();
}

class _AppNotificationsScreenState extends State<AppNotificationsScreen> {
  late final NotificationHistoryController controller;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<NotificationHistoryController>()
        ? Get.find<NotificationHistoryController>()
        : Get.put(NotificationHistoryController());
  }

  @override
  void dispose() {
    // Don't leave parent search sticky when leaving this screen.
    if (controller.searchQuery.value.isNotEmpty) {
      controller.updateSearch('');
    }
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back',
          onPressed: () {
            if (controller.searchQuery.value.isNotEmpty) {
              controller.updateSearch('');
            }
            Get.back();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.appName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Obx(() {
              controller.readStateVersion.value;
              final total = controller.notifications
                  .where((n) => n.packageName == widget.packageName)
                  .length;
              final unread =
                  controller.unreadCountForApp(widget.packageName);
              return Text(
                unread > 0
                    ? '$unread unread · $total messages'
                    : '$total messages',
                style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.color
                        ?.withValues(alpha: 0.7),
                    fontSize: 13),
              );
            }),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(
            color: Theme.of(context).textTheme.titleLarge?.color),
        actions: [
          IconButton(
            icon: FaIcon(
              _showSearch
                  ? FontAwesomeIcons.xmark
                  : FontAwesomeIcons.magnifyingGlass,
              size: 16,
            ),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.6),
              Theme.of(context).colorScheme.surface,
              Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withValues(alpha: 0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _showSearch
                    ? Padding(
                        key: const ValueKey('appSearch'),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: TextField(
                          controller: _searchController,
                          onChanged: controller.updateSearch,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Search ${widget.appName}...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                controller.updateSearch('');
                              },
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .cardColor
                                .withValues(alpha: 0.9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('noAppSearch')),
              ),
              Expanded(
                child: Obx(() {
                  controller.readStateVersion.value;
                  controller.searchQuery.value;
                  final senderGroups = controller
                      .getNotificationsBySender(widget.packageName);
                  final senders = senderGroups.keys.toList();

                  if (senders.isEmpty) {
                    return const Center(child: Text('No messages found'));
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: senders.length,
                    itemBuilder: (context, index) {
                      final name = senders[index];
                      final messages = senderGroups[name]!;
                      final latest = messages.first;
                      final unread = controller.unreadCountForSender(
                          widget.packageName, name);
                      final total = messages.length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          elevation: unread > 0 ? 3 : 2,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          child: InkWell(
                            onTap: () {
                              Get.toNamed(
                                Routes.notificationChat,
                                arguments: {
                                  'packageName': widget.packageName,
                                  'appName': widget.appName,
                                  'senderName': name,
                                  'appColor': widget.appColor,
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0.8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      if (latest.senderIcon != null)
                                        _SenderIcon(
                                          senderIcon: latest.senderIcon!,
                                          size: 52,
                                          appIcon: _AppIcon(
                                            packageName: widget.packageName,
                                            size: 52,
                                            fallbackLabel: safeInitial(name),
                                            fallbackColor: widget.appColor,
                                          ),
                                        )
                                      else
                                        _AppIcon(
                                          packageName: widget.packageName,
                                          size: 52,
                                          fallbackLabel: safeInitial(name),
                                          fallbackColor: widget.appColor,
                                        ),
                                      if (unread > 0)
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00ACC1),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surface,
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              unread > 99
                                                  ? '99+'
                                                  : unread.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: unread > 0
                                                      ? FontWeight.w800
                                                      : FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              DateFormat('hh:mm a').format(
                                                  latest.timestamp),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: unread > 0
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: unread > 0
                                                    ? const Color(0xFF00ACC1)
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(
                                                            alpha: 0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          latest.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: unread > 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(
                                                    alpha:
                                                        unread > 0 ? 0.85 : 0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          unread > 0
                                              ? '$unread unread · $total messages'
                                              : '$total messages',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
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

/// Conversation for one sender — message-by-message with avatar, name, time, text.
class SenderConversationScreen extends StatefulWidget {
  final String packageName;
  final String appName;
  final String senderName;
  final Color appColor;

  const SenderConversationScreen({
    super.key,
    required this.packageName,
    required this.appName,
    required this.senderName,
    required this.appColor,
  });

  @override
  State<SenderConversationScreen> createState() =>
      _SenderConversationScreenState();
}

class _SenderConversationScreenState extends State<SenderConversationScreen> {
  late final NotificationHistoryController controller;
  final _scrollController = ScrollController();
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<NotificationHistoryController>()
        ? Get.find<NotificationHistoryController>()
        : Get.put(NotificationHistoryController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.markConversationRead(widget.packageName, widget.senderName);
      _scrollToBottomOnce();
    });
  }

  void _scrollToBottomOnce() {
    if (_didInitialScroll) return;
    if (!_scrollController.hasClients) return;
    _didInitialScroll = true;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Back to ${widget.appName}',
          onPressed: () => Get.back(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Obx(() {
              controller.readStateVersion.value;
              final msgs = controller.conversationMessages(
                widget.packageName,
                widget.senderName,
              );
              final icon = msgs.isNotEmpty ? msgs.last.senderIcon : null;
              if (icon != null) {
                return _SenderIcon(
                  senderIcon: icon,
                  size: 40,
                  appIcon: _AppIcon(
                    packageName: widget.packageName,
                    size: 40,
                    fallbackLabel: safeInitial(widget.senderName),
                    fallbackColor: widget.appColor,
                  ),
                );
              }
              return _AppIcon(
                packageName: widget.packageName,
                size: 40,
                fallbackLabel: safeInitial(widget.senderName),
                fallbackColor: widget.appColor,
              );
            }),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Obx(() {
                    controller.readStateVersion.value;
                    final count = controller
                        .conversationMessages(
                            widget.packageName, widget.senderName)
                        .length;
                    return Text(
                      '${widget.appName} · $count messages',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      body: Container(
        color: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F8),
        child: Obx(() {
          controller.notifications.length;
          controller.readStateVersion.value;
          final sortedMessages = controller.conversationMessages(
            widget.packageName,
            widget.senderName,
          );

          if (sortedMessages.isEmpty) {
            return const Center(child: Text('No messages yet'));
          }

          final dateGroups = <String, List<NotificationModel>>{};
          for (final m in sortedMessages) {
            final dateStr = DateFormat('EEEE, MMM dd yyyy').format(m.timestamp);
            dateGroups.putIfAbsent(dateStr, () => []).add(m);
          }

          final dates = dateGroups.keys.toList();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottomOnce();
          });

          return ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final date = dates[index];
              final dayMessages = dateGroups[date]!;

              return Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      child: Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                  ...dayMessages.map(
                    (m) => _ChatBubble(
                      message: m,
                      appColor: widget.appColor,
                      appName: widget.appName,
                      packageName: widget.packageName,
                      onTap: () => _openMessageDetail(context, m),
                    ),
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }

  void _openMessageDetail(BuildContext context, NotificationModel message) {
    controller.markMessageRead(message);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (message.senderIcon != null)
                      _SenderIcon(
                        senderIcon: message.senderIcon!,
                        size: 56,
                        appIcon: _AppIcon(
                          packageName: widget.packageName,
                          size: 56,
                          fallbackLabel: safeInitial(message.senderName),
                          fallbackColor: widget.appColor,
                        ),
                      )
                    else
                      _AppIcon(
                        packageName: widget.packageName,
                        size: 56,
                        fallbackLabel: safeInitial(message.senderName),
                        fallbackColor: widget.appColor,
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.senderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.appName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('EEE, MMM dd · hh:mm a')
                                .format(message.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F4F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final NotificationModel message;
  final Color appColor;
  final String appName;
  final String packageName;
  final VoidCallback onTap;

  const _ChatBubble({
    required this.message,
    required this.appColor,
    required this.appName,
    required this.packageName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = !message.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: unread
                  ? (isDark
                      ? appColor.withValues(alpha: 0.18)
                      : appColor.withValues(alpha: 0.08))
                  : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: unread
                    ? appColor.withValues(alpha: 0.35)
                    : (isDark ? Colors.white10 : Colors.black12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.senderIcon != null)
                  _SenderIcon(
                    senderIcon: message.senderIcon!,
                    size: 44,
                    appIcon: _AppIcon(
                      packageName: packageName,
                      size: 44,
                      fallbackLabel: safeInitial(message.senderName),
                      fallbackColor: appColor,
                    ),
                  )
                else
                  _AppIcon(
                    packageName: packageName,
                    size: 44,
                    fallbackLabel: safeInitial(message.senderName),
                    fallbackColor: appColor,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight:
                                    unread ? FontWeight.w800 : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('hh:mm a').format(message.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  unread ? FontWeight.w600 : FontWeight.normal,
                              color: unread
                                  ? appColor
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.normal,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: unread ? 0.92 : 0.75),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            appName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          const Spacer(),
                          if (unread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: appColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Text(
                              'Tap for details',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.35),
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
    );
  }
}

