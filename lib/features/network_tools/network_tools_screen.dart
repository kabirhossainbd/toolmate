import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'network_tools_controller.dart';

class NetworkToolsScreen extends GetView<NetworkToolsController> {
  const NetworkToolsScreen({super.key});

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
            Text('Network Tools', style: openSansBold.copyWith(fontSize: 18)),
        actions: [
          Obx(
            () => IconButton(
              onPressed: controller.isRefreshing.value
                  ? null
                  : controller.refreshAll,
              icon: controller.isRefreshing.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(
                label: controller.statusLabel.value,
                types: controller.connectionTypes.toList(),
              ),
              const SizedBox(height: 16),
              Text('Wi‑Fi details',
                  style: openSansSemiBold.copyWith(fontSize: 14)),
              const SizedBox(height: 10),
              _InfoTile(title: 'SSID / Name', value: controller.wifiName.value),
              _InfoTile(title: 'IP address', value: controller.wifiIP.value),
              _InfoTile(title: 'BSSID', value: controller.wifiBSSID.value),
              _InfoTile(title: 'Gateway', value: controller.wifiGateway.value),
              const SizedBox(height: 16),
              Text(
                'Note: Wi‑Fi name may require location permission on Android.',
                style: openSansRegular.copyWith(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.label, required this.types});

  final String label;
  final List<String> types;

  @override
  Widget build(BuildContext context) {
    final online = !label.toLowerCase().contains('offline');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppUi.accentGradient(
          online ? AppUi.brandTeal : Colors.blueGrey,
        ),
        borderRadius: BorderRadius.circular(AppUi.radiusMd),
        boxShadow: AppUi.softGlow(online ? AppUi.brandTeal : Colors.blueGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: openSansBold.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          if (types.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Interfaces: ${types.join(', ')}',
              style: openSansRegular.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: openSansMedium.copyWith(fontSize: 13)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: openSansSemiBold.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
