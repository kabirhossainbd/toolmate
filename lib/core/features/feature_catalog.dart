import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../app_ui.dart';
import 'feature_item.dart';

/// Catalog entries use translation keys for title / subtitle / category.
class FeatureCatalog {
  FeatureCatalog._();

  static const List<FeatureItem> all = [
    FeatureItem(
      id: 'storageAnalyzer',
      title: 'storage',
      subtitle: 'storage_sub',
      icon: FontAwesomeIcons.hardDrive,
      color: AppUi.brandBlue,
      route: '/storage-analyzer',
      category: 'essentials',
    ),
    FeatureItem(
      id: 'videoDownloader',
      title: 'downloader',
      subtitle: 'downloader_sub',
      icon: FontAwesomeIcons.download,
      color: AppUi.brandPink,
      route: '/video-downloader',
      category: 'essentials',
    ),
    FeatureItem(
      id: 'notificationHistory',
      title: 'notifications',
      subtitle: 'notifications_sub',
      icon: FontAwesomeIcons.solidBell,
      color: AppUi.brandOrange,
      route: '/notification-history',
      category: 'essentials',
    ),
    FeatureItem(
      id: 'notes',
      title: 'notes',
      subtitle: 'notes_sub',
      icon: FontAwesomeIcons.noteSticky,
      color: AppUi.brandTeal,
      route: '/notes',
      category: 'utilities',
    ),
    FeatureItem(
      id: 'unitConverter',
      title: 'converter',
      subtitle: 'converter_sub',
      icon: FontAwesomeIcons.rulerCombined,
      color: AppUi.brandPurple,
      route: '/unit-converter',
      category: 'utilities',
    ),
    FeatureItem(
      id: 'clipboardManager',
      title: 'clipboard',
      subtitle: 'clipboard_sub',
      icon: FontAwesomeIcons.clipboard,
      color: AppUi.brandDeep,
      route: '/clipboard',
      category: 'utilities',
    ),
  ];

  static const categories = ['essentials', 'utilities'];

  static List<FeatureItem> byCategory(String category) =>
      all.where((f) => f.category == category).toList();

  static FeatureItem? byId(String id) {
    for (final f in all) {
      if (f.id == id) return f;
    }
    return null;
  }
}
