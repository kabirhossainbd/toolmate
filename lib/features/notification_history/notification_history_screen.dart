import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_ui.dart';
import '../../core/style.dart';
import '../../core/widgets/smooth_scroll.dart';
import '../../routes/app_routes.dart';
import 'notification_history_controller.dart';
import 'notification_model.dart';

// In-memory icon cache to avoid repeated async calls
final Map<String, Uint8List?> _iconCache = {};

Future<bool> _confirmDeleteNotification(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.35)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result == true;
}

Widget _swipeDeleteBackground() {
  return Container(
    alignment: Alignment.centerRight,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.redAccent,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
        SizedBox(width: 6),
        Text(
          'Delete',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

/// Compact notification UI tokens — smaller type + consistent brand colors.
class _NotifUi {
  static const Color accent = AppUi.brandBlue;
  static const Color unread = AppUi.brandOrange;
  static const Color bubbleLight = Color(0xFFFFFFFF);
  static const Color bubbleDark = Color(0xFF1A1F27);
  static const Color pageLight = Color(0xFFF0F3F7);
  static const Color pageDark = Color(0xFF0E1116);

  static Color card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFF161B22) : Colors.white;
  }

  static Color muted(BuildContext context, [double a = 0.5]) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: a);

  static Color border(BuildContext context, {bool unread = false}) {
    if (unread) return accent.withValues(alpha: 0.35);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
  }
}

String _formatMessageShare(NotificationModel m, String appName) {
  final time = DateFormat('MMM dd, yyyy · hh:mm a').format(m.timestamp);
  return '${m.senderName} ($appName)\n$time\n\n${m.text}';
}

Future<void> _copyMessage(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  Get.snackbar(
    'Copied',
    'Message copied to clipboard',
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 1),
    margin: const EdgeInsets.all(12),
    borderRadius: 12,
  );
}

Future<void> _shareMessage(NotificationModel m, String appName) async {
  await SharePlus.instance.share(
    ShareParams(
      text: _formatMessageShare(m, appName),
      subject: 'Message from ${m.senderName}',
    ),
  );
}

void _showCopyShareSheet(
  BuildContext context, {
  required NotificationModel message,
  required String appName,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  Get.bottomSheet(
    SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F27) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.copy_rounded, size: 20, color: _NotifUi.accent),
              title: const Text('Copy message', style: TextStyle(fontSize: 13)),
              onTap: () {
                Get.back();
                _copyMessage(message.text);
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.ios_share_rounded, size: 20, color: _NotifUi.accent),
              title: const Text('Share message', style: TextStyle(fontSize: 13)),
              onTap: () {
                Get.back();
                _shareMessage(message, appName);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen>
    with WidgetsBindingObserver {
  late final NotificationHistoryController controller;
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = Get.isRegistered<NotificationHistoryController>()
        ? Get.find<NotificationHistoryController>()
        : Get.put(NotificationHistoryController(), permanent: true);
    // Sync BG isolate writes when opening the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.refreshFromDisk(forceReopen: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.refreshFromDisk(forceReopen: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    final opening = !_showSearch;
    setState(() => _showSearch = opening);
    if (!opening) {
      _searchController.clear();
      // Clear after frame so SizeTransition stays smooth.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearSearch();
      });
    }
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
          'Notifications',
          style: openSansBold.copyWith(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.filter, size: 14),
            tooltip: 'Filter',
            onPressed: () => _showFilterBottomSheet(context),
          ),
          IconButton(
            icon: FaIcon(
              _showSearch ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass,
              size: 14,
            ),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            tooltip: 'More',
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: SafeArea(
          child: Column(
            children: [
              // Animated search bar — AnimatedSize avoids full-subtree SizeTransition cost
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _showSearch
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 13),
                          onChanged: controller.updateSearch,
                          decoration: InputDecoration(
                            hintText: 'Search notifications...',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: _NotifUi.muted(context, 0.45),
                            ),
                            prefixIcon: Icon(
                              CupertinoIcons.search,
                              size: 18,
                              color: _NotifUi.muted(context, 0.45),
                            ),
                            suffixIcon: IconButton(
                              icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
                              onPressed: () {
                                _searchController.clear();
                                controller.clearSearch();
                              },
                            ),
                            filled: true,
                            fillColor: _NotifUi.card(context),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Obx(() {
                final hasActive = controller.timeFilter.value != 'All' ||
                    controller.selectedApp.value != 'All' ||
                    controller.unreadOnly.value ||
                    controller.sortOrder.value != 'New First';
                if (!hasActive) return const SizedBox.shrink();
                return SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear all',
                            style: TextStyle(fontSize: 11, color: _NotifUi.accent)),
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
                    color: _NotifUi.accent),
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
                            activeThumbColor: _NotifUi.accent,
                            onChanged: (v) {
                              controller.toggleUnreadOnly(v);
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'SORT BY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
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
                        backgroundColor: _NotifUi.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('Apply filters',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
              Icon(Icons.notifications_off_outlined,
                  size: 48, color: _NotifUi.muted(context, 0.35)),
              const SizedBox(height: 12),
              Text(
                'No notifications found',
                style: TextStyle(
                  fontSize: 13,
                  color: _NotifUi.muted(context, 0.55),
                ),
              ),
            ],
          ),
        );
      }

      final appKeys = controller.groupedNotifications.keys.toList();

      return ListView.builder(
        physics: SmoothScroll.physics,
        cacheExtent: SmoothScroll.cacheExtent,
        addAutomaticKeepAlives: false,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
        itemCount: appKeys.length,
        itemBuilder: (context, index) {
          final packageName = appKeys[index];
          final appNotifs = controller.groupedNotifications[packageName]!;
          final latestNotif = appNotifs.first;
          final unreadCount = controller.unreadCountForApp(packageName);
          final totalCount = appNotifs.length;
          final hasUnread = unreadCount > 0;

          return Dismissible(
            key: ValueKey('app_$packageName'),
            direction: DismissDirection.endToStart,
            background: _swipeDeleteBackground(),
            confirmDismiss: (_) => _confirmDeleteNotification(
              context,
              title: 'Delete notifications?',
              message:
                  'Remove all saved notifications from ${_getAppName(packageName)}? This cannot be undone.',
            ),
            onDismissed: (_) => controller.deleteByPackage(packageName),
            child: SmoothListTile(
              borderColor: _NotifUi.border(context, unread: hasUnread),
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
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _AppIcon(
                        packageName: packageName,
                        size: 42,
                        fallbackLabel: safeInitial(_getAppName(packageName)),
                        fallbackColor: _getAppColor(packageName),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _NotifUi.unread,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _NotifUi.card(context),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              unreadCount > 99
                                  ? '99+'
                                  : unreadCount.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                                _getAppName(packageName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('hh:mm a')
                                  .format(latestNotif.timestamp),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: hasUnread
                                    ? _NotifUi.accent
                                    : _NotifUi.muted(context, 0.45),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          latestNotif.title.isNotEmpty
                              ? '${latestNotif.title}: ${latestNotif.text}'
                              : latestNotif.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                            color: _NotifUi.muted(
                                context, hasUnread ? 0.72 : 0.55),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasUnread
                              ? '$unreadCount unread · $totalCount'
                              : '$totalCount messages',
                          style: TextStyle(
                            fontSize: 10,
                            color: _NotifUi.muted(context, 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: _NotifUi.muted(context, 0.3),
                  ),
                ],
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
    if (packageName.contains('twitter') || packageName.contains('x.com')) {
      return 'X (Twitter)';
    }
    if (packageName.contains('gmail')) return 'Gmail';
    if (packageName.contains('chrome')) return 'Chrome';
    if (packageName.contains('tiktok') ||
        packageName.contains('musically') ||
        packageName.contains('aweme')) {
      return 'TikTok';
    }
    if (packageName.contains('spotify')) return 'Spotify';
    final parts = packageName.split('.');
    return parts.last.capitalizeFirst ?? packageName;
  }

  Color _getAppColor(String packageName) {
    if (packageName.contains('orca')) return const Color(0xFF0084FF);
    if (packageName.contains('whatsapp')) return const Color(0xFF25D366);
    if (packageName.contains('youtube')) return const Color(0xFFFF0000);
    if (packageName.contains('teams')) return const Color(0xFF6264A7);
    if (packageName.contains('truecaller')) return const Color(0xFF0087FF);
    if (packageName.contains('mms')) return const Color(0xFF1E88E5);
    if (packageName.contains('instagram')) return const Color(0xFFE1306C);
    if (packageName.contains('telegram')) return const Color(0xFF229ED9);
    if (packageName.contains('gmail')) return const Color(0xFFEA4335);
    if (packageName.contains('spotify')) return const Color(0xFF1DB954);
    if (packageName.contains('tiktok') || packageName.contains('musically')) {
      return const Color(0xFF111111);
    }
    return AppUi.brandBlue;
  }
}

class _ActiveFilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _ActiveFilterPill({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        onDeleted: onClear,
        deleteIconColor: _NotifUi.accent,
        backgroundColor: _NotifUi.accent.withValues(alpha: 0.12),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _NotifUi.accent
              : Colors.grey.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : unselectedText,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11.5,
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
      controller.clearSearch();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    final opening = !_showSearch;
    setState(() => _showSearch = opening);
    if (!opening) {
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.clearSearch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? _NotifUi.pageDark : _NotifUi.pageLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          tooltip: 'Back',
          onPressed: () {
            if (controller.searchQuery.value.isNotEmpty) {
              controller.clearSearch();
            }
            Get.back();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.appName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
            Obx(() {
              controller.readStateVersion.value;
              controller.notifications.length;
              final total = controller.groupedNotifications[widget.packageName]
                      ?.length ??
                  controller.notifications
                      .where((n) => n.packageName == widget.packageName)
                      .length;
              final unread = controller.unreadCountForApp(widget.packageName);
              return Text(
                unread > 0
                    ? '$unread unread · $total'
                    : '$total messages',
                style: TextStyle(
                  color: _NotifUi.muted(context, 0.55),
                  fontSize: 11,
                ),
              );
            }),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: FaIcon(
              _showSearch
                  ? FontAwesomeIcons.xmark
                  : FontAwesomeIcons.magnifyingGlass,
              size: 14,
            ),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showSearch
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                      child: TextField(
                        controller: _searchController,
                        onChanged: controller.updateSearch,
                        autofocus: true,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search ${widget.appName}...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: _NotifUi.muted(context, 0.45),
                          ),
                          prefixIcon: Icon(Icons.search,
                              size: 18, color: _NotifUi.muted(context, 0.45)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              controller.clearSearch();
                            },
                          ),
                          filled: true,
                          fillColor: _NotifUi.card(context),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Obx(() {
                controller.readStateVersion.value;
                controller.searchQuery.value;
                controller.timeFilter.value;
                controller.unreadOnly.value;
                final senderGroups =
                    controller.getNotificationsBySender(widget.packageName);
                final senders = senderGroups.keys.toList();

                if (senders.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages found',
                      style: TextStyle(
                        fontSize: 13,
                        color: _NotifUi.muted(context, 0.55),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  physics: SmoothScroll.physics,
                  cacheExtent: SmoothScroll.cacheExtent,
                  addAutomaticKeepAlives: false,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: senders.length,
                  itemBuilder: (context, index) {
                    final name = senders[index];
                    final messages = senderGroups[name]!;
                    final latest = messages.first;
                    final unread = controller.unreadCountForSender(
                        widget.packageName, name);
                    final total = messages.length;
                    final hasUnread = unread > 0;

                    return Dismissible(
                      key: ValueKey('sender_${widget.packageName}_$name'),
                      direction: DismissDirection.endToStart,
                      background: _swipeDeleteBackground(),
                      confirmDismiss: (_) => _confirmDeleteNotification(
                        context,
                        title: 'Delete conversation?',
                        message:
                            'Remove all saved messages from $name? This cannot be undone.',
                      ),
                      onDismissed: (_) => controller.deleteBySender(
                        widget.packageName,
                        name,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: _NotifUi.card(context),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color:
                                  _NotifUi.border(context, unread: hasUnread),
                            ),
                          ),
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
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      if (latest.senderIcon != null)
                                        _SenderIcon(
                                          senderIcon: latest.senderIcon!,
                                          size: 40,
                                          appIcon: _AppIcon(
                                            packageName: widget.packageName,
                                            size: 40,
                                            fallbackLabel: safeInitial(name),
                                            fallbackColor: widget.appColor,
                                          ),
                                        )
                                      else
                                        _AppIcon(
                                          packageName: widget.packageName,
                                          size: 40,
                                          fallbackLabel: safeInitial(name),
                                          fallbackColor: widget.appColor,
                                        ),
                                      if (hasUnread)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 15, minHeight: 15),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 3.5),
                                            decoration: BoxDecoration(
                                              color: _NotifUi.unread,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              border: Border.all(
                                                color: _NotifUi.card(context),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(
                                              unread > 99
                                                  ? '99+'
                                                  : unread.toString(),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: hasUnread
                                                      ? FontWeight.w700
                                                      : FontWeight.w600,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              DateFormat('hh:mm a')
                                                  .format(latest.timestamp),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: hasUnread
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: hasUnread
                                                    ? _NotifUi.accent
                                                    : _NotifUi.muted(
                                                        context, 0.45),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          latest.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            height: 1.3,
                                            fontWeight: hasUnread
                                                ? FontWeight.w500
                                                : FontWeight.w400,
                                            color: _NotifUi.muted(context,
                                                hasUnread ? 0.72 : 0.52),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          hasUnread
                                              ? '$unread unread · $total'
                                              : '$total messages',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                _NotifUi.muted(context, 0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: _NotifUi.muted(context, 0.3),
                                  ),
                                ],
                              ),
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
    );
  }
}

/// Widget that loads the real launcher icon for a given package, with gradient fallback.
class _AppIcon extends StatefulWidget {
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

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  Future<Uint8List?>? _iconFuture;

  @override
  void initState() {
    super.initState();
    _iconFuture = _resolveIcon();
  }

  @override
  void didUpdateWidget(covariant _AppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _iconFuture = _resolveIcon();
    }
  }

  Future<Uint8List?> _resolveIcon() async {
    if (_iconCache.containsKey(widget.packageName)) {
      return _iconCache[widget.packageName];
    }
    try {
      final app = await InstalledApps.getAppInfo(widget.packageName);
      _iconCache[widget.packageName] = app?.icon;
      return app?.icon;
    } catch (_) {
      _iconCache[widget.packageName] = null;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final fallbackColor = widget.fallbackColor;

    // Hot path: cache hit — no FutureBuilder.
    if (_iconCache.containsKey(widget.packageName)) {
      final cached = _iconCache[widget.packageName];
      if (cached != null) {
        return _IconCircle(size: size, bytes: cached);
      }
      return _FallbackIcon(
        size: size,
        label: widget.fallbackLabel,
        color: fallbackColor,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _iconFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return _IconCircle(size: size, bytes: snapshot.data!);
        }
        return _FallbackIcon(
          size: size,
          label: widget.fallbackLabel,
          color: fallbackColor,
        );
      },
    );
  }
}

class _IconCircle extends StatelessWidget {
  final double size;
  final Uint8List bytes;

  const _IconCircle({required this.size, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  final double size;
  final String label;
  final Color color;

  const _FallbackIcon({
    required this.size,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.45,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
      return ClipOval(
        child: Image.memory(
          senderIcon,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (context, error, stack) => appIcon,
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
      backgroundColor: isDark ? _NotifUi.pageDark : _NotifUi.pageLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
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
                  size: 34,
                  appIcon: _AppIcon(
                    packageName: widget.packageName,
                    size: 34,
                    fallbackLabel: safeInitial(widget.senderName),
                    fallbackColor: widget.appColor,
                  ),
                );
              }
              return _AppIcon(
                packageName: widget.packageName,
                size: 34,
                fallbackLabel: safeInitial(widget.senderName),
                fallbackColor: widget.appColor,
              );
            }),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  Obx(() {
                    controller.readStateVersion.value;
                    final count = controller
                        .conversationMessages(
                            widget.packageName, widget.senderName)
                        .length;
                    return Text(
                      '${widget.appName} · $count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _NotifUi.muted(context, 0.5),
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
      ),
      body: Obx(() {
        controller.notifications.length;
        controller.readStateVersion.value;
        final sortedMessages = controller.conversationMessages(
          widget.packageName,
          widget.senderName,
        );

        if (sortedMessages.isEmpty) {
          return Center(
            child: Text(
              'No messages yet',
              style: TextStyle(fontSize: 13, color: _NotifUi.muted(context, 0.55)),
            ),
          );
        }

        // Flatten date headers + messages so ListView can virtualize every row.
        final rows = <Object>[];
        String? lastDate;
        for (final m in sortedMessages) {
          final dateStr = DateFormat('EEE, MMM dd').format(m.timestamp);
          if (dateStr != lastDate) {
            rows.add(dateStr);
            lastDate = dateStr;
          }
          rows.add(m);
        }

        return ListView.builder(
          controller: _scrollController,
          physics: SmoothScroll.physics,
          cacheExtent: SmoothScroll.cacheExtent,
          addAutomaticKeepAlives: false,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 20),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row is String) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    row,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _NotifUi.muted(context, 0.5),
                    ),
                  ),
                ),
              );
            }

            final m = row as NotificationModel;
            return Dismissible(
              key: ValueKey('msg_${m.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 22),
              ),
              confirmDismiss: (_) => _confirmDeleteNotification(
                context,
                title: 'Delete message?',
                message:
                    'Remove this saved notification permanently? This cannot be undone.',
              ),
              onDismissed: (_) => controller.deleteNotification(m.id),
              child: _ChatBubble(
                message: m,
                appColor: widget.appColor,
                appName: widget.appName,
                packageName: widget.packageName,
                onTap: () => _openMessageDetail(context, m),
                onLongPress: () => _showCopyShareSheet(
                  context,
                  message: m,
                  appName: widget.appName,
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _openMessageDetail(BuildContext context, NotificationModel message) {
    controller.markMessageRead(message);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? _NotifUi.bubbleDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
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
                        size: 42,
                        appIcon: _AppIcon(
                          packageName: widget.packageName,
                          size: 42,
                          fallbackLabel: safeInitial(message.senderName),
                          fallbackColor: widget.appColor,
                        ),
                      )
                    else
                      _AppIcon(
                        packageName: widget.packageName,
                        size: 42,
                        fallbackLabel: safeInitial(message.senderName),
                        fallbackColor: widget.appColor,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.senderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.appName,
                            style: TextStyle(
                              fontSize: 11,
                              color: _NotifUi.muted(context, 0.5),
                            ),
                          ),
                          Text(
                            DateFormat('EEE, MMM dd · hh:mm a')
                                .format(message.timestamp),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: _NotifUi.muted(context, 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF1F4F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _copyMessage(message.text);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy', style: TextStyle(fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _NotifUi.accent,
                          side: BorderSide(
                              color: _NotifUi.accent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _shareMessage(message, widget.appName);
                        },
                        icon: const Icon(Icons.ios_share_rounded, size: 16),
                        label:
                            const Text('Share', style: TextStyle(fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _NotifUi.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
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
  final VoidCallback onLongPress;

  const _ChatBubble({
    required this.message,
    required this.appColor,
    required this.appName,
    required this.packageName,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unread = !message.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
            decoration: BoxDecoration(
              color: unread
                  ? (isDark
                      ? _NotifUi.accent.withValues(alpha: 0.14)
                      : _NotifUi.accent.withValues(alpha: 0.07))
                  : (isDark ? _NotifUi.bubbleDark : _NotifUi.bubbleLight),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _NotifUi.border(context, unread: unread),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: appColor.withValues(alpha: 0.18),
                  child: Text(
                    safeInitial(message.senderName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: appColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('hh:mm a').format(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: unread
                                  ? _NotifUi.accent
                                  : _NotifUi.muted(context, 0.42),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight:
                              unread ? FontWeight.w500 : FontWeight.w400,
                          color: _NotifUi.muted(context, unread ? 0.88 : 0.7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (unread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _NotifUi.unread,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Text(
                              appName,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: _NotifUi.muted(context, 0.38),
                              ),
                            ),
                          const Spacer(),
                          _MiniAction(
                            icon: Icons.copy_rounded,
                            tooltip: 'Copy',
                            onTap: () => _copyMessage(message.text),
                          ),
                          const SizedBox(width: 2),
                          _MiniAction(
                            icon: Icons.ios_share_rounded,
                            tooltip: 'Share',
                            onTap: () => _shareMessage(message, appName),
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

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 15, color: _NotifUi.accent),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
    );
  }
}

