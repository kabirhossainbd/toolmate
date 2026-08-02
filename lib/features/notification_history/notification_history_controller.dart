import 'dart:async';

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

  /// Precomputed unread counts — O(1) lookups in list tiles.
  final unreadByApp = <String, int>{}.obs;
  final unreadBySender = <String, int>{}.obs;

  Timer? _searchDebounce;
  Timer? _refreshDebounce;
  StreamSubscription? _captureSub;
  bool _refreshing = false;

  static String _senderKey(String packageName, String senderName) =>
      '$packageName\u0000$senderName';

  @override
  void onInit() {
    super.onInit();
    box = Hive.box<NotificationModel>('notifications');
    _loadFromHive();
    _initService();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _refreshDebounce?.cancel();
    _captureSub?.cancel();
    super.onClose();
  }

  void _loadFromHive() {
    _deduplicateHive();
    notifications.assignAll(box.values.toList().reversed);
    _updateUniqueApps();
    _rebuildUnreadCaches();
    _applyFilters();
  }

  /// Soft reload from disk without closing the box (avoids main-isolate hitch).
  Future<void> refreshFromDisk() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      // Prefer a cheap in-memory sync; only reopen if lengths diverge badly.
      final diskCount = box.length;
      final memCount = notifications.length;
      if ((diskCount - memCount).abs() > 2 || diskCount == 0) {
        // Rare path: reopen once if BG writes aren't visible yet.
        final name = box.name;
        if (box.isOpen) await box.close();
        box = await Hive.openBox<NotificationModel>(name);
      }
      _loadFromHive();
    } catch (_) {
      // Keep existing in-memory list if reopen fails.
    } finally {
      _refreshing = false;
    }
  }

  void _scheduleSoftRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      refreshFromDisk();
    });
  }

  void _ingestCaptured(Map<dynamic, dynamic>? event) {
    if (event == null) return;
    try {
      final map = Map<String, dynamic>.from(event);
      final notif = NotificationModel.fromJson(map);

      // Skip if we already have this id for the package.
      final exists = notifications.any(
        (n) => n.id == notif.id && n.packageName == notif.packageName,
      );
      if (exists) return;

      notifications.insert(0, notif);
      _updateUniqueApps();
      _rebuildUnreadCaches();
      _applyFilters();
      // Avatar may arrive on disk later — soft refresh without closing every time.
      _scheduleSoftRefresh();
    } catch (_) {
      _scheduleSoftRefresh();
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

      _captureSub =
          FlutterBackgroundService().on('onNotificationCaptured').listen((event) {
        _ingestCaptured(event);
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

  void _rebuildUnreadCaches() {
    final byApp = <String, int>{};
    final bySender = <String, int>{};
    for (final n in notifications) {
      if (n.isRead) continue;
      byApp[n.packageName] = (byApp[n.packageName] ?? 0) + 1;
      final key = _senderKey(n.packageName, n.senderName);
      bySender[key] = (bySender[key] ?? 0) + 1;
    }
    unreadByApp.assignAll(byApp);
    unreadBySender.assignAll(bySender);
  }

  /// Debounced search — avoids full filter on every keystroke.
  void updateSearch(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), _applyFilters);
  }

  /// Immediate clear (search close / reset) — no debounce lag.
  void clearSearch() {
    _searchDebounce?.cancel();
    if (searchQuery.value.isEmpty) {
      _applyFilters();
      return;
    }
    searchQuery.value = '';
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
    _searchDebounce?.cancel();
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
    final selected = selectedApp.value;
    final unread = unreadOnly.value;
    final query = searchQuery.value.toLowerCase();
    final hasQuery = query.isNotEmpty;
    final order = sortOrder.value;

    final result = <NotificationModel>[];
    for (final e in notifications) {
      if (selected != 'All' && e.packageName != selected) continue;
      if (unread && e.isRead) continue;
      if (!_inTimeRange(e)) continue;
      if (hasQuery) {
        final title = e.title.toLowerCase();
        final text = e.text.toLowerCase();
        final pkg = e.packageName.toLowerCase();
        if (!title.contains(query) &&
            !text.contains(query) &&
            !pkg.contains(query)) {
          continue;
        }
      }
      result.add(e);
    }

    switch (order) {
      case 'New First':
        result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Old First':
        result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'A-Z':
        result.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'Z-A':
        result.sort(
            (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
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
    final query = searchQuery.value.toLowerCase();
    final hasQuery = query.isNotEmpty;
    final unread = unreadOnly.value;

    final appNotifs = <NotificationModel>[];
    for (final n in notifications) {
      if (n.packageName != packageName) continue;
      if (unread && n.isRead) continue;
      if (!_inTimeRange(n)) continue;
      if (hasQuery) {
        if (!n.title.toLowerCase().contains(query) &&
            !n.text.toLowerCase().contains(query)) {
          continue;
        }
      }
      appNotifs.add(n);
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
    final list = <NotificationModel>[];
    for (final n in notifications) {
      if (n.packageName == packageName && n.senderName == senderName) {
        list.add(n);
      }
    }
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  int unreadCountForApp(String packageName) =>
      unreadByApp[packageName] ?? 0;

  int unreadCountForSender(String packageName, String senderName) =>
      unreadBySender[_senderKey(packageName, senderName)] ?? 0;

  int get totalUnread {
    var total = 0;
    for (final v in unreadByApp.values) {
      total += v;
    }
    return total;
  }

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
      _rebuildUnreadCaches();
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
      _rebuildUnreadCaches();
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
    _rebuildUnreadCaches();
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
    unreadByApp.clear();
    unreadBySender.clear();
    _updateUniqueApps();
    resetFilters();
    readStateVersion.value++;
  }
}
