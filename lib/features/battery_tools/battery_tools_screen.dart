import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'battery_tools_controller.dart';

class BatteryToolsScreen extends GetView<BatteryToolsController> {
  const BatteryToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        title:
            Text('Battery Tools', style: openSansBold.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.refreshBattery,
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          final pct = controller.level.value;
          final color = _colorFor(pct);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppUi.accentGradient(color),
                  borderRadius: BorderRadius.circular(AppUi.radiusMd),
                  boxShadow: AppUi.softGlow(color),
                ),
                child: Column(
                  children: [
                    Icon(_iconFor(pct), color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      '$pct%',
                      style: openSansBold.copyWith(
                        fontSize: 42,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.stateLabel,
                      style: openSansMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.isInBatterySaveMode.value
                          ? 'Battery Saver: On'
                          : 'Battery Saver: Off',
                      style: openSansRegular.copyWith(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Tips', style: openSansSemiBold.copyWith(fontSize: 15)),
              const SizedBox(height: 10),
              for (final tip in controller.tips)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline_rounded,
                          size: 18, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tip,
                          style: openSansRegular.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Color _colorFor(int pct) {
    if (pct <= 15) return AppUi.brandPink;
    if (pct <= 40) return AppUi.brandOrange;
    if (pct <= 70) return AppUi.brandBlue;
    return AppUi.brandTeal;
  }

  IconData _iconFor(int pct) {
    if (pct <= 15) return Icons.battery_1_bar_rounded;
    if (pct <= 40) return Icons.battery_3_bar_rounded;
    if (pct <= 70) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }
}
