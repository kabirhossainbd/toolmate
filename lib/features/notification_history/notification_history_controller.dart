import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'notification_model.dart';
import 'package:share_plus/share_plus.dart';

class NotificationHistoryController extends GetxController {
  late Box<NotificationModel> box;

  final notifications = <NotificationModel>[].obs;
  final filteredNotifications = <NotificationModel>[].obs;

  final groupedNotifications = <String, List<NotificationModel>>{}.obs;

  final searchQuery = ''.obs;
  final selectedApp = 'All'.obs;

  final uniqueApps = <String>['All'].obs;
  final isServiceRunning = false.obs;

  final sortOrder = 'New First'.obs;

  /// Time range: All | Today | Yesterday | This Week | This Month | Custom
  final timeFilter = 'All'.obs;
  final Rxn<DateTime> customStart = Rxn<DateTime>();
  final Rxn<DateTime> customEnd = Rxn<DateTime>();
  final unreadOnly = false.obs;

  /// Bumps when read-state changes so nested screens rebuild.
  final readStateVersion = 0.obs;

  @override
  void onInit() {
    super.onInit();
    box = Hive.box<NotificationModel>('notifications');
    _loadFromHive();
    _initService();
  }

  void _loadFromHive() {
    _deduplicateHive();
    notifications.assignAll(box.values.toList().reversed);
    _updateUniqueApps();
    _applyFilters();
  }

  /// Re-open box so BG-isolate writes (with avatar) become visible.
  Future<void> refreshFromDisk() async {
    try {
      final name = box.name;
      if (box.isOpen) await box.close();
      box = await Hive.openBox<NotificationModel>(name);
      _loadFromHive();
    } catch (_) {
      // Keep existing in-memory list if reopen fails.
    }
  }

  void _deduplicateHive() {
    final seen = <String>{};
    final keysToDelete = <dynamic>[];

    final allKeys = box.keys.toList().reversed.toList();
    for (final key in allKeys) {
      final notif = box.get(key);
      if (notif == null) continue;
      if (notif.id.isEmpty || seen.add(notif.id)) continue;
      keysToDelete.add(key);
    }

    for (final key in keysToDelete) {
      box.delete(key);
    }
  }

  Future<void> _initService() async {
    bool status = await NotificationListenerService.isPermissionGranted();
    if (!status) {
      status = await NotificationListenerService.requestPermission();
    }

    if (status) {
      if (isServiceRunning.value) return;
      isServiceRunning.value = true;

      FlutterBackgroundService().on('onNotificationCaptured').listen((event) async {
        // BG isolate wrote Hive (with avatar). Refresh main isolate from disk.
        await Future.delayed(const Duration(milliseconds: 150));
        await refreshFromDisk();
      });

      final isRunning = await FlutterBackgroundService().isRunning();
      if (!isRunning) {
        FlutterBackgroundService().startService();
      }
    } else {
      Get.snackbar(
        'Permission Denied',
        'Notification access is required to capture notifications.',
      );
    }
  }

  void _updateUniqueApps() {
    final apps = notifications.map((e) => e.packageName).toSet().toList();
    apps.sort();
    uniqueApps.assignAll(['All', ...apps]);
  }

  void updateSearch(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void updateAppFilter(String app) {
    selectedApp.value = app;
    _applyFilters();
  }

  void updateSortOrder(String order) {
    sortOrder.value = order;
    _applyFilters();
  }

  void updateTimeFilter(String filter) {
    timeFilter.value = filter;
    if (filter != 'Custom') {
      customStart.value = null;
      customEnd.value = null;
    }
    _applyFilters();
  }

  void updateCustomRange(DateTime start, DateTime end) {
    customStart.value = DateTime(start.year, start.month, start.day);
    customEnd.value = DateTime(end.year, end.month, end.day, 23, 59, 59);
    timeFilter.value = 'Custom';
    _applyFilters();
  }

  void toggleUnreadOnly(bool value) {
    unreadOnly.value = value;
    _applyFilters();
  }

  void resetFilters() {
    searchQuery.value = '';
    selectedApp.value = 'All';
    sortOrder.value = 'New First';
    timeFilter.value = 'All';
    customStart.value = null;
    customEnd.value = null;
    unreadOnly.value = false;
    _applyFilters();
  }

  bool _inTimeRange(NotificationModel n) {
    final t = n.timestamp;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (timeFilter.value) {
      case 'Today':
        return !t.isBefore(todayStart);
      case 'Yesterday':
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        return !t.isBefore(yesterdayStart) && t.isBefore(todayStart);
      case 'This Week':
        final weekStart =
            todayStart.subtract(Duration(days: todayStart.weekday - 1));
        return !t.isBefore(weekStart);
      case 'This Month':
        final monthStart = DateTime(now.year, now.month, 1);
        return !t.isBefore(monthStart);
      case 'Custom':
        final start = customStart.value;
        final end = customEnd.value;
        if (start == null || end == null) return true;
        return !t.isBefore(start) && !t.isAfter(end);
      case 'All':
      default:
        return true;
    }
  }

  void _applyFilters() {
    var result = notifications.toList();

    if (selectedApp.value != 'All') {
      result = result.where((e) => e.packageName == selectedApp.value).toList();
    }

    if (unreadOnly.value) {
      result = result.where((e) => !e.isRead).toList();
    }

    result = result.where(_inTimeRange).toList();

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result
          .where((e) =>
              e.title.toLowerCase().contains(query) ||
              e.text.toLowerCase().contains(query) ||
              e.packageName.toLowerCase().contains(query))
          .toList();
    }

    switch (sortOrder.value) {
      case 'New First':
        result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Old First':
        result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'A-Z':
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Z-A':
        result.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
    }

    filteredNotifications.assignAll(result);
    _groupNotifications();
  }

  void _groupNotifications() {
    final Map<String, List<NotificationModel>> grouped = {};
    for (var notif in filteredNotifications) {
      grouped.putIfAbsent(notif.packageName, () => []).add(notif);
    }

    // Keep map key order aligned with sort preference for app list.
    if (sortOrder.value == 'A-Z' || sortOrder.value == 'Z-A') {
      final keys = grouped.keys.toList()
        ..sort((a, b) {
          final cmp = a.toLowerCase().compareTo(b.toLowerCase());
          return sortOrder.value == 'A-Z' ? cmp : -cmp;
        });
      groupedNotifications.value = {for (final k in keys) k: grouped[k]!};
    } else {
      groupedNotifications.value = grouped;
    }
  }

  Map<String, List<NotificationModel>> getNotificationsBySender(
      String packageName) {
    var appNotifs =
        notifications.where((n) => n.packageName == packageName).toList();

    if (unreadOnly.value) {
      appNotifs = appNotifs.where((n) => !n.isRead).toList();
    }
    appNotifs = appNotifs.where(_inTimeRange).toList();

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      appNotifs = appNotifs
          .where((n) =>
              n.title.toLowerCase().contains(query) ||
              n.text.toLowerCase().contains(query))
          .toList();
    }

    appNotifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final groups = <String, List<NotificationModel>>{};
    for (var n in appNotifs) {
      groups.putIfAbsent(n.senderName, () => []).add(n);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final timeA = groups[a]!.first.timestamp;
        final timeB = groups[b]!.first.timestamp;
        return timeB.compareTo(timeA);
      });

    return {for (var k in sortedKeys) k: groups[k]!};
  }

  List<NotificationModel> conversationMessages(
      String packageName, String senderName) {
    final list = notifications
        .where((n) =>
            n.packageName == packageName && n.senderName == senderName)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  int unreadCountForApp(String packageName) {
    return notifications
        .where((n) => n.packageName == packageName && !n.isRead)
        .length;
  }

  int unreadCountForSender(String packageName, String senderName) {
    return notifications
        .where((n) =>
            n.packageName == packageName &&
            n.senderName == senderName &&
            !n.isRead)
        .length;
  }

  int get totalUnread => notifications.where((n) => !n.isRead).length;

  Future<void> markAllRead() async {
    var changed = false;
    for (final n in box.values) {
      if (!n.isRead) {
        n.isRead = true;
        await n.save();
        changed = true;
      }
    }
    for (final n in notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      readStateVersion.value++;
      notifications.refresh();
      _applyFilters();
    }
  }

  Future<void> markConversationRead(
      String packageName, String senderName) async {
    var changed = false;

    for (final n in box.values) {
      if (n.packageName == packageName &&
          n.senderName == senderName &&
          !n.isRead) {
        n.isRead = true;
        await n.save();
        changed = true;
      }
    }

    for (final n in notifications) {
      if (n.packageName == packageName &&
          n.senderName == senderName &&
          !n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }

    if (changed) {
      readStateVersion.value++;
      notifications.refresh();
      _applyFilters();
    }
  }

  Future<void> markMessageRead(NotificationModel message) async {
    if (message.isRead) return;
    message.isRead = true;
    if (message.isInBox) {
      await message.save();
    } else {
      for (final n in box.values) {
        if (n.id == message.id &&
            n.packageName == message.packageName &&
            n.timestamp == message.timestamp) {
          n.isRead = true;
          await n.save();
          break;
        }
      }
    }
    readStateVersion.value++;
    notifications.refresh();
    _applyFilters();
  }

  Future<void> exportNotifications({String format = 'text'}) async {
    if (filteredNotifications.isEmpty) {
      Get.snackbar('Empty', 'No notifications to export.');
      return;
    }

    if (format == 'csv' || format == 'excel') {
      final buffer = StringBuffer();
      buffer.writeln('App,Package,Sender,Message,Time,Read');
      for (final n in filteredNotifications) {
        String esc(String v) => '"${v.replaceAll('"', '""')}"';
        buffer.writeln([
          esc(n.packageName.split('.').last),
          esc(n.packageName),
          esc(n.title),
          esc(n.text),
          esc(n.timestamp.toIso8601String()),
          n.isRead ? 'yes' : 'no',
        ].join(','));
      }
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: 'Notification History Export (CSV)',
        ),
      );
      return;
    }

    final buffer = StringBuffer('Notification History Export\n\n');
    for (final n in filteredNotifications) {
      buffer.writeln('App: ${n.packageName}');
      buffer.writeln('Time: ${n.timestamp}');
      buffer.writeln('Sender: ${n.title}');
      buffer.writeln('Message: ${n.text}');
      buffer.writeln('Read: ${n.isRead ? 'yes' : 'no'}');
      buffer.writeln('--------------------------');
    }

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Notification History Export',
      ),
    );
  }

  void clearHistory() {
    box.clear();
    notifications.clear();
    filteredNotifications.clear();
    groupedNotifications.clear();
    _updateUniqueApps();
    resetFilters();
    readStateVersion.value++;
  }
}
