import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:get/get.dart';

class BatteryToolsController extends GetxController {
  final _battery = Battery();

  final level = 0.obs;
  final state = BatteryState.unknown.obs;
  final isInBatterySaveMode = false.obs;
  final isLoading = true.obs;

  StreamSubscription<BatteryState>? _stateSub;

  @override
  void onInit() {
    super.onInit();
    refreshBattery();
    _stateSub = _battery.onBatteryStateChanged.listen((s) {
      state.value = s;
      refreshBattery();
    });
  }

  @override
  void onClose() {
    _stateSub?.cancel();
    super.onClose();
  }

  Future<void> refreshBattery() async {
    try {
      level.value = await _battery.batteryLevel;
      state.value = await _battery.batteryState;
      isInBatterySaveMode.value = await _battery.isInBatterySaveMode;
    } catch (_) {
      // Platform may not support all queries.
    } finally {
      isLoading.value = false;
    }
  }

  String get stateLabel {
    switch (state.value) {
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.full:
        return 'Full';
      case BatteryState.connectedNotCharging:
        return 'Connected (not charging)';
      case BatteryState.unknown:
        return 'Unknown';
    }
  }

  List<String> get tips {
    final pct = level.value;
    final tips = <String>[];
    if (pct <= 15) {
      tips.addAll([
        'Enable Battery Saver / Low Power Mode now.',
        'Lower screen brightness and turn off Always-On Display.',
        'Disable Wi‑Fi / Bluetooth if unused; use airplane mode if offline.',
        'Close background apps and pause large downloads.',
      ]);
    } else if (pct <= 40) {
      tips.addAll([
        'Reduce refresh rate / animation if available.',
        'Limit location and background sync for heavy apps.',
        'Prefer dark theme on OLED screens.',
      ]);
    } else if (pct <= 70) {
      tips.addAll([
        'Keep adaptive battery enabled.',
        'Uninstall unused apps that drain overnight.',
        'Avoid extreme heat while charging.',
      ]);
    } else {
      tips.addAll([
        'Battery looks healthy — avoid constant 100% trickle charging.',
        'Use original / certified chargers when possible.',
        'Calibrate occasionally by a full charge cycle if readings drift.',
      ]);
    }
    if (isInBatterySaveMode.value) {
      tips.insert(0, 'Battery Saver is already on — great.');
    }
    if (state.value == BatteryState.charging && pct > 80) {
      tips.add('Consider unplugging near 80–90% for long-term battery health.');
    }
    return tips;
  }
}
