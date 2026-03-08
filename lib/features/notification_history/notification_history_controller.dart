import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'notification_model.dart';
import 'package:share_plus/share_plus.dart';

class NotificationHistoryController extends GetxController {
  late Box<NotificationModel> box;
  
  final notifications = <NotificationModel>[].obs;
  final filteredNotifications = <NotificationModel>[].obs;
  
  // Grouped by packageName
  // Map<String, List<NotificationModel>>
  final groupedNotifications = <String, List<NotificationModel>>{}.obs;
  
  final searchQuery = ''.obs;
  final selectedApp = 'All'.obs;
  
  final uniqueApps = <String>['All'].obs;
  final isServiceRunning = false.obs;
  
  // Sorting options: 'New First', 'Old First', 'A-Z', 'Z-A'
  final sortOrder = 'New First'.obs;

  @override
  void onInit() {
    super.onInit();
    box = Hive.box<NotificationModel>('notifications');
    _loadFromHive();
    _initService();
  }

  void _loadFromHive() {
    _deduplicateHive(); // Clean up any duplicates stored in previous sessions
    notifications.assignAll(box.values.toList().reversed);
    _updateUniqueApps();
    _applyFilters();
  }

  /// Removes duplicate entries from Hive that share the same notification ID.
  /// Keeps only the latest (last stored) entry for each ID.
  void _deduplicateHive() {
    final seen = <String>{};
    final keysToDelete = <dynamic>[];

    // Iterate in reverse so we keep the LAST (most recent) entry for each ID
    final allKeys = box.keys.toList().reversed.toList();
    for (final key in allKeys) {
      final notif = box.get(key);
      if (notif == null) continue;
      if (notif.id.isEmpty || seen.add(notif.id)) continue;
      // Duplicate found — mark for deletion
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
      isServiceRunning.value = true;
      
      // Listen for notifications captured by the background service
      FlutterBackgroundService().on('onNotificationCaptured').listen((event) {
        if (event == null) return;
        final newNotif = NotificationModel.fromJson(Map<String, dynamic>.from(event));
        
        // Add to memory list
        notifications.insert(0, newNotif);
        _updateUniqueApps();
        _applyFilters();
      });

      // Also ensure the service is running
      final isRunning = await FlutterBackgroundService().isRunning();
      if (!isRunning) {
        FlutterBackgroundService().startService();
      }
    } else {
       Get.snackbar('Permission Denied', 'Notification access is required to capture notifications.');
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

  void resetFilters() {
    searchQuery.value = '';
    selectedApp.value = 'All';
    sortOrder.value = 'New First';
    _applyFilters();
  }

  void _applyFilters() {
    var result = notifications.toList();
    
    if (selectedApp.value != 'All') {
      result = result.where((e) => e.packageName == selectedApp.value).toList();
    }
    
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      result = result.where((e) => 
        e.title.toLowerCase().contains(query) || 
        e.text.toLowerCase().contains(query) ||
        e.packageName.toLowerCase().contains(query)).toList();
    }

    // Apply Sorting
    switch (sortOrder.value) {
      case 'New First':
        result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Old First':
        result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'A-Z':
        result.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Z-A':
        result.sort((a, b) => b.title.compareTo(a.title));
        break;
    }
    
    filteredNotifications.assignAll(result);
    _groupNotifications();
  }

  void _groupNotifications() {
    final Map<String, List<NotificationModel>> grouped = {};
    for (var notif in filteredNotifications) {
      if (!grouped.containsKey(notif.packageName)) {
        grouped[notif.packageName] = [];
      }
      grouped[notif.packageName]!.add(notif);
    }
    groupedNotifications.value = grouped;
  }

  /// Groups notifications for a specific [packageName] by their [title] (Sender).
  Map<String, List<NotificationModel>> getNotificationsBySender(String packageName) {
    var appNotifs = notifications.where((n) => n.packageName == packageName).toList();
    
    // Apply search if active
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      appNotifs = appNotifs.where((n) => 
        n.title.toLowerCase().contains(query) || 
        n.text.toLowerCase().contains(query)
      ).toList();
    }

    // Always sort by time (latest first) within the app view
    appNotifs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final groups = <String, List<NotificationModel>>{};
    for (var n in appNotifs) {
      final senderName = n.title.isNotEmpty ? n.title : 'Unknown';
      groups.putIfAbsent(senderName, () => []).add(n);
    }
    
    // Sort senders by latest message timestamp
    final sortedKeys = groups.keys.toList()..sort((a, b) {
      final timeA = groups[a]!.first.timestamp;
      final timeB = groups[b]!.first.timestamp;
      return timeB.compareTo(timeA);
    });

    return { for (var k in sortedKeys) k : groups[k]! };
  }

  Future<void> exportNotifications() async {
    if (filteredNotifications.isEmpty) {
      Get.snackbar('Empty', 'No notifications to export.');
      return;
    }

    String exportText = "Notification History Export:\n\n";
    for (var n in filteredNotifications) {
      exportText += "App: ${n.packageName}\nTime: ${n.timestamp.toString()}\nTitle: ${n.title}\nContent: ${n.text}\n--------------------------\n";
    }

    // ignore: deprecated_member_use
    await Share.share(exportText, subject: 'Notification History Export');
  }

  void clearHistory() {
    box.clear();
    notifications.clear();
    filteredNotifications.clear();
    groupedNotifications.clear();
    _updateUniqueApps();
    selectedApp.value = 'All';
  }
}
