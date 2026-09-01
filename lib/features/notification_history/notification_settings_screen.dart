import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/settings/app_settings_controller.dart';
import '../../core/style.dart';
import 'notification_history_controller.dart';

const _accent = Color(0xFF00ACC1);

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  AppSettingsController get _settings => Get.find<AppSettingsController>();

  NotificationHistoryController? get _history {
    if (!Get.isRegistered<NotificationHistoryController>()) return null;
    return Get.find<NotificationHistoryController>();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E1116) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Notifications',
          style: openSansBold.copyWith(fontSize: 17, color: Colors.white),
        ),
      ),
      body: Obx(() {
        return ListView(
          children: [
            const SizedBox(height: 8),
            _tile(
              title: 'Notification History Size',
              subtitle:
                  'Choose how many notifications to keep. Applies to saved history.',
              titleColor: titleColor,
              subColor: subColor,
              trailing: Text(
                _settings.historySizeLabel(),
                style: TextStyle(fontSize: 13, color: _accent),
              ),
              onTap: () => _pickHistorySize(context),
            ),
            _tile(
              title: 'Group Notifications',
              subtitle: 'Group notifications based on app name',
              titleColor: titleColor,
              subColor: subColor,
              trailing: Switch.adaptive(
                value: _settings.groupNotifications.value,
                activeThumbColor: _accent,
                onChanged: _settings.setGroupNotifications,
              ),
            ),
            _tile(
              title: 'Disable Notification History',
              subtitle:
                  'This will temporarily stop storing notifications in history',
              titleColor: titleColor,
              subColor: subColor,
              trailing: Switch.adaptive(
                value: _settings.historyDisabled.value,
                activeThumbColor: _accent,
                onChanged: _settings.setHistoryDisabled,
              ),
            ),
            _tile(
              title: 'Save Non-Removable Notifications',
              subtitle:
                  'Eg: Music players, browser downloads, battery savers, memory cleaners, phone calls etc. (Not recommended, it creates duplicate notifications)',
              titleColor: titleColor,
              subColor: subColor,
              trailing: Switch.adaptive(
                value: _settings.saveOngoingNotifications.value,
                activeThumbColor: _accent,
                onChanged: _settings.setSaveOngoingNotifications,
              ),
            ),
            _tile(
              title: 'Clear Notifications',
              subtitle:
                  'This will clear all stored notifications. You can not undo it.',
              titleColor: titleColor,
              subColor: subColor,
              onTap: _confirmClear,
            ),
            _tile(
              title: 'Auto Delete Notifications',
              subtitle: _settings.autoDeleteLabel(),
              titleColor: titleColor,
              subColor: subColor,
              onTap: () => _pickAutoDelete(context),
            ),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, height: 1.35, color: subColor),
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  void _pickHistorySize(BuildContext context) {
    _showChoiceSheet(
      context,
      title: 'History size',
      options: [
        for (final n in AppSettingsController.historySizeOptions)
          (n <= 0 ? 'Unlimited' : '$n', n),
      ],
      selected: _settings.historySize.value,
      onPick: (value) {
        _settings.setHistorySize(value);
        _history?.applyRetention();
      },
    );
  }

  void _pickAutoDelete(BuildContext context) {
    _showChoiceSheet(
      context,
      title: 'Auto delete',
      options: const [
        ('Never', 0),
        ('After 7 days', 7),
        ('After 30 days', 30),
        ('After 90 days', 90),
      ],
      selected: _settings.autoDeleteDays.value,
      onPick: (value) {
        _settings.setAutoDeleteDays(value);
        _history?.applyRetention();
      },
    );
  }

  void _showChoiceSheet(
    BuildContext context, {
    required String title,
    required List<(String, int)> options,
    required int selected,
    required void Function(int) onPick,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  dense: true,
                  title: Text(option.$1, style: const TextStyle(fontSize: 14)),
                  trailing: selected == option.$2
                      ? const Icon(Icons.check_rounded, color: _accent, size: 20)
                      : null,
                  onTap: () {
                    Get.back();
                    onPick(option.$2);
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
      middleText:
          'This will delete all saved notifications permanently. You cannot undo it.',
      textConfirm: 'Clear',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      onConfirm: () {
        _history?.clearHistory();
        Get.back();
        Get.snackbar('Cleared', 'All notifications were deleted');
      },
    );
  }
}
