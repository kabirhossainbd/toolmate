import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/background_service.dart';
import 'notification_model.dart';

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
  Timer? _periodicSync;
  StreamSubscription? _captureSub;
  StreamSubscription? _foregroundSub;
  bool _refreshing = false;
  final Set<String> _seenIds = {};
  final Map<String, int> _recentFingerprints = {};
  /// contentKey → notification id for fast merge lookups.
  final Map<String, String> _contentKeyToId = {};
  /// androidKey → notification id for shade update-in-place.
  final Map<String, String> _androidKeyToId = {};

  /// Identical content merges within this window (same spam/OTP/status).
  static const _mergeWindow = Duration(minutes: 45);
  /// Same Android shade key updates merge within this window.
  static const _keyUpdateWindow = Duration(hours: 6);

  static String _senderKey(String packageName, String senderName) =>
      '$packageName\u0000$senderName';

  void _indexNotif(NotificationModel n) {
    _contentKeyToId[n.contentKey] = n.id;
    if (n.androidKey.isNotEmpty) {
      _androidKeyToId[n.androidKey] = n.id;
    }
  }

  void _rebuildMergeIndexes(Iterable<NotificationModel> list) {
    _contentKeyToId.clear();
    _androidKeyToId.clear();
    for (final n in list) {
      _indexNotif(n);
    }
  }

  NotificationModel? _findById(String id) {
    for (final n in notifications) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Find an existing row to merge into (same shade key or same content).
  NotificationModel? _findMergeTarget({
    required String packageName,
    required String title,
    required String text,
    required String androidKey,
    required DateTime when,
  }) {
    if (androidKey.isNotEmpty) {
      final id = _androidKeyToId[androidKey];
      final existing = id == null ? null : _findById(id);
      if (existing != null &&
          when.difference(existing.timestamp).abs() <= _keyUpdateWindow) {
        return existing;
      }
    }

    final key = notificationContentKey(
      packageName: packageName,
      title: title,
      text: text,
    );
    final id = _contentKeyToId[key];
    final existing = id == null ? null : _findById(id);
    if (existing != null &&
        when.difference(existing.timestamp).abs() <= _mergeWindow) {
      return existing;
    }
    return null;
  }

  Future<bool> _mergeIntoExisting(
    NotificationModel existing, {
    required String title,
    required String text,
    required DateTime when,
    Uint8List? icon,
    String androidKey = '',
  }) async {
    final age = when.difference(existing.timestamp).abs();
    // Dual-path (BG invoke + JSONL drain / foreground) within a few seconds
    // should not inflate the stack count.
    final bumpCount = age > const Duration(seconds: 4);
    if (bumpCount) {
      existing.count = (existing.count < 1 ? 1 : existing.count) + 1;
    }
    if (when.isAfter(existing.timestamp)) {
      existing.timestamp = when;
    }
    // Prefer newer body/title when shade updates in place.
    if (text.trim().isNotEmpty) existing.text = sanitizeUtf16(text.trim());
    if (title.trim().isNotEmpty) existing.title = sanitizeUtf16(title.trim());
    if (icon != null && icon.isNotEmpty) existing.senderIcon = icon;
    if (androidKey.isNotEmpty) existing.androidKey = androidKey;
    if (bumpCount) existing.isRead = false;
    try {
      await existing.save();
    } catch (_) {}
    _indexNotif(existing);
    // Move to top of in-memory list.
    notifications.removeWhere((n) => n.id == existing.id);
    notifications.insert(0, existing);
    notifications.refresh();
    _rebuildUnreadCaches();
    _applyFilters();
    return true;
  }

  @override
  void onInit() {
    super.onInit();
    box = Hive.box<NotificationModel>('notifications');
    _loadFromHive();
    _initService();
    // BG isolate writes to a JSONL queue (not Hive) — drain periodically.
    _periodicSync = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_drainPendingQueue()),
    );
  }

  /// Import captures written by the background isolate while UI was dead.
  Future<void> _drainPendingQueue() async {
    try {
      final imported = await BackgroundService.drainPendingNotifications(
        (json) async {
          await _upsertFromMap(Map<String, dynamic>.from(json));
        },
      );
      if (imported > 0) {
        _updateUniqueApps();
        _rebuildUnreadCaches();
        _applyFilters();
      }
    } catch (_) {
      // Keep UI responsive if drain fails.
    }
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    _refreshDebounce?.cancel();
    _periodicSync?.cancel();
    _captureSub?.cancel();
    _foregroundSub?.cancel();
    super.onClose();
  }

  void _loadFromHive() {
    _deduplicateHive();
    final list = box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifications.assignAll(list);
    _seenIds
      ..clear()
      ..addAll(list.map((e) => e.id));
    _rebuildMergeIndexes(list);
    _updateUniqueApps();
    _rebuildUnreadCaches();
    _applyFilters();
  }

  /// Re-open box so BG-isolate Hive writes become visible to the UI isolate.
  Future<void> refreshFromDisk({bool forceReopen = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final name = box.name;
      final before = box.isOpen ? box.length : -1;
      if (forceReopen || !box.isOpen) {
        if (box.isOpen) await box.close();
        box = await Hive.openBox<NotificationModel>(name);
      } else if ((box.length - notifications.length).abs() > 0) {
        if (box.isOpen) await box.close();
        box = await Hive.openBox<NotificationModel>(name);
      }
      // Only rebuild UI if something changed.
      if (forceReopen || box.length != before || box.length != notifications.length) {
        _loadFromHive();
      }
    } catch (_) {
      // Keep existing in-memory list if reopen fails.
    } finally {
      _refreshing = false;
    }
  }

  void _scheduleSoftRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_drainPendingQueue());
    });
  }

  bool _isRecentDuplicate(String packageName, String title, String text) {
    final fp = notificationContentKey(
      packageName: packageName,
      title: title,
      text: text,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _recentFingerprints[fp];
    // Short burst guard for dual-path race (BG + foreground).
    if (last != null && now - last < 2500) return true;
    _recentFingerprints[fp] = now;
    if (_recentFingerprints.length > 400) {
      final cutoff = now - 120000;
      _recentFingerprints.removeWhere((_, ts) => ts < cutoff);
    }
    return false;
  }

  Future<void> _upsertFromMap(Map<String, dynamic> map) async {
    final packageName = map['packageName']?.toString() ?? '';
    if (packageName.isEmpty) return;

    final titleRaw = (map['title'] ?? map['sender'] ?? '').toString().trim();
    final textRaw = (map['text'] ?? map['content'] ?? '').toString().trim();
    if (titleRaw.isEmpty && textRaw.isEmpty) return;

    final title = titleRaw.isNotEmpty ? titleRaw : 'No title';
    final text = textRaw.isNotEmpty ? textRaw : 'No content';
    final androidKey =
        (map['androidKey'] ?? map['key'] ?? '').toString().trim();

    DateTime when;
    try {
      final post = map['postTime'];
      if (post is int && post > 0) {
        when = DateTime.fromMillisecondsSinceEpoch(post);
      } else if (map['timestamp'] != null) {
        when = DateTime.parse(map['timestamp'].toString());
      } else {
        when = DateTime.now();
      }
    } catch (_) {
      when = DateTime.now();
    }

    if (_isRecentDuplicate(packageName, title, text)) {
      // Still try merge so count bumps instead of silent drop when possible.
    }

    final mergeTarget = _findMergeTarget(
      packageName: packageName,
      title: title,
      text: text,
      androidKey: androidKey,
      when: when,
    );
    if (mergeTarget != null) {
      Uint8List? icon;
      final rawIcon = map['senderIcon'];
      if (rawIcon is Uint8List) {
        icon = rawIcon;
      } else if (rawIcon is List) {
        icon = Uint8List.fromList(List<int>.from(rawIcon));
      }
      await _mergeIntoExisting(
        mergeTarget,
        title: title,
        text: text,
        when: when,
        icon: icon,
        androidKey: androidKey,
      );
      return;
    }

    final idFromMap = map['id']?.toString() ?? '';
    final androidId = map['androidId']?.toString() ?? '0';
    final uniqueId = idFromMap.isNotEmpty
        ? idFromMap
        : '${packageName}_${androidId}_${Object.hash(title, text)}';
    if (_seenIds.contains(uniqueId)) return;

    Uint8List? icon;
    final rawIcon = map['senderIcon'];
    if (rawIcon is Uint8List) {
      icon = rawIcon;
    } else if (rawIcon is List) {
      icon = Uint8List.fromList(List<int>.from(rawIcon));
    }
    if (icon != null && icon.length > 100 * 1024) icon = null;

    final notif = NotificationModel(
      id: uniqueId,
      packageName: packageName,
      title: title,
      text: text,
      timestamp: when,
      senderIcon: icon,
      androidKey: androidKey,
      count: 1,
    );

    await box.add(notif);
    _seenIds.add(uniqueId);
    _indexNotif(notif);
    notifications.insert(0, notif);
  }

  void _ingestCaptured(Map<dynamic, dynamic>? event) {
    if (event == null) return;
    unawaited(() async {
      try {
        await _upsertFromMap(Map<String, dynamic>.from(event));
        _updateUniqueApps();
        _rebuildUnreadCaches();
        _applyFilters();
        _scheduleSoftRefresh();
      } catch (_) {
        _scheduleSoftRefresh();
      }
    }());
  }

  /// Foreground backup listener — catches events even if BG invoke is delayed.
  Future<void> _persistForegroundEvent(ServiceNotificationEvent event) async {
    try {
      if (event.hasRemoved == true) return;
      final packageName = event.packageName ?? '';
      if (packageName.isEmpty) return;

      final title = event.displayTitle;
      final content = (event.content ?? '').trim();
      if (title == 'No title' && content.isEmpty) return;
      final textSafe = content.isNotEmpty ? content : 'No content';

      if (event.onGoing == true) {
        final lower = '$title $textSafe'.toLowerCase();
        if (lower.contains('%') ||
            lower.contains('downloading') ||
            lower.contains('upload') ||
            lower.contains('playing')) {
          return;
        }
      }

      final when = (event.postTime != null && event.postTime! > 0)
          ? DateTime.fromMillisecondsSinceEpoch(event.postTime!)
          : DateTime.now();
      final androidId = event.id?.toString() ?? '0';
      final uniqueId =
          '${packageName}_${androidId}_${Object.hash(title, textSafe)}';

      Uint8List? icon = event.largeIcon;
      if (icon != null && icon.length > 100 * 1024) icon = null;

      await _upsertFromMap({
        'id': uniqueId,
        'packageName': packageName,
        'title': title,
        'text': textSafe,
        'timestamp': when.toIso8601String(),
        'postTime': event.postTime,
        'senderIcon': icon,
        'androidKey': event.key ?? '',
        'androidId': androidId,
        'isRead': false,
      });
      _updateUniqueApps();
      _rebuildUnreadCaches();
      _applyFilters();
    } catch (_) {
      // Ignore malformed events.
    }
  }

  void _deduplicateHive() {
    // 1) Drop exact id duplicates.
    // 2) Merge same contentKey within merge window into one row with summed count.
    final byId = <String, dynamic>{};
    final keysToDelete = <dynamic>[];

    for (final key in box.keys.toList()) {
      final notif = box.get(key);
      if (notif == null) continue;
      if (notif.id.isEmpty) {
        keysToDelete.add(key);
        continue;
      }
      if (byId.containsKey(notif.id)) {
        keysToDelete.add(key);
      } else {
        byId[notif.id] = key;
      }
    }

    for (final key in keysToDelete) {
      box.delete(key);
    }

    final keepers = <String, NotificationModel>{}; // contentKey -> keeper
    final mergeDelete = <dynamic>[];

    final values = box.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final n in values) {
      final ck = n.contentKey;
      final existing = keepers[ck];
      if (existing == null) {
        keepers[ck] = n;
        continue;
      }
      if (existing.timestamp.difference(n.timestamp).abs() <= _mergeWindow) {
        existing.count = (existing.count < 1 ? 1 : existing.count) +
            (n.count < 1 ? 1 : n.count);
        if (n.timestamp.isAfter(existing.timestamp)) {
          existing.timestamp = n.timestamp;
          existing.text = n.text;
          existing.title = n.title;
          if (n.senderIcon != null) existing.senderIcon = n.senderIcon;
        }
        if (n.androidKey.isNotEmpty && existing.androidKey.isEmpty) {
          existing.androidKey = n.androidKey;
        }
        if (!n.isRead) existing.isRead = false;
        try {
          existing.save();
        } catch (_) {}
        mergeDelete.add(n.key);
      } else {
        // Outside window — keep as separate historical row with unique synthetic key.
        keepers['$ck|${n.id}'] = n;
      }
    }

    for (final key in mergeDelete) {
      box.delete(key);
    }
  }

  Future<void> _initService() async {
    bool status = await NotificationListenerService.isPermissionGranted();
    if (!status) {
      status = await NotificationListenerService.requestPermission();
    }

    if (!status) {
      Get.snackbar(
        'Permission Denied',
        'Notification access is required to capture notifications.',
      );
      return;
    }

    if (isServiceRunning.value) return;
    isServiceRunning.value = true;

    _captureSub =
        FlutterBackgroundService().on('onNotificationCaptured').listen((event) {
      _ingestCaptured(event);
    });

    // Dual-listen in UI isolate so we don't miss events when invoke is delayed.
    try {
      _foregroundSub = NotificationListenerService.notificationsStream.listen(
        (event) {
          unawaited(_persistForegroundEvent(event));
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Android-only API.
    }

    final isRunning = await FlutterBackgroundService().isRunning();
    if (!isRunning) {
      await FlutterBackgroundService().startService();
    }

    // Pull anything currently in the shade.
    try {
      final active = await NotificationListenerService.getActiveNotifications();
      for (final event in active) {
        await _persistForegroundEvent(event);
      }
    } catch (_) {}

    await _drainPendingQueue();
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
      // Normalize so "John" / "John " / casing variants stay one conversation.
      final sender = sanitizeUtf16(n.senderName).trim();
      final key = sender.isEmpty ? 'Unknown' : sender;
      groups.putIfAbsent(key, () => []).add(n);
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
    final want = sanitizeUtf16(senderName).trim();
    final list = <NotificationModel>[];
    for (final n in notifications) {
      if (n.packageName != packageName) continue;
      if (sanitizeUtf16(n.senderName).trim() != want) continue;
      list.add(n);
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

  void deleteNotification(String id) {
    if (id.isEmpty) return;
    final keys = <dynamic>[];
    for (final key in box.keys.toList()) {
      final n = box.get(key);
      if (n?.id == id) keys.add(key);
    }
    for (final key in keys) {
      box.delete(key);
    }
    _seenIds.remove(id);
    _loadFromHive();
    readStateVersion.value++;
  }

  void deleteByPackage(String packageName) {
    if (packageName.isEmpty) return;
    final keys = <dynamic>[];
    final removedIds = <String>{};
    for (final key in box.keys.toList()) {
      final n = box.get(key);
      if (n?.packageName == packageName) {
        keys.add(key);
        if (n != null) removedIds.add(n.id);
      }
    }
    for (final key in keys) {
      box.delete(key);
    }
    _seenIds.removeAll(removedIds);
    _loadFromHive();
    readStateVersion.value++;
  }

  void deleteBySender(String packageName, String senderName) {
    if (packageName.isEmpty) return;
    final keys = <dynamic>[];
    final removedIds = <String>{};
    for (final key in box.keys.toList()) {
      final n = box.get(key);
      if (n == null) continue;
      if (n.packageName == packageName && n.senderName == senderName) {
        keys.add(key);
        removedIds.add(n.id);
      }
    }
    for (final key in keys) {
      box.delete(key);
    }
    _seenIds.removeAll(removedIds);
    _loadFromHive();
    readStateVersion.value++;
  }
}
