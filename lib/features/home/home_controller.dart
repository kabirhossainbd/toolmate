import 'package:get/get.dart';

import '../../core/features/feature_catalog.dart';
import '../../core/features/feature_item.dart';

class HomeController extends GetxController {
  List<String> get categories => FeatureCatalog.categories;

  List<FeatureItem> featuresFor(String category) =>
      FeatureCatalog.byCategory(category);

  void openFeature(FeatureItem feature) {
    Get.toNamed(feature.route);
  }
}
