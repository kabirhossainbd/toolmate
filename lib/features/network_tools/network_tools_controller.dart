import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkToolsController extends GetxController {
  final connectivity = Connectivity();
  final networkInfo = NetworkInfo();

  final statusLabel = 'Checking…'.obs;
  final connectionTypes = <String>[].obs;
  final wifiName = '—'.obs;
  final wifiIP = '—'.obs;
  final wifiBSSID = '—'.obs;
  final wifiGateway = '—'.obs;
  final isRefreshing = false.obs;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    _sub = connectivity.onConnectivityChanged.listen((_) => refreshAll());
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  Future<void> refreshAll() async {
    isRefreshing.value = true;
    try {
      await _loadConnectivity();
      await _loadWifiInfo();
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> _loadConnectivity() async {
    final results = await connectivity.checkConnectivity();
    connectionTypes.assignAll(results.map(_labelFor).toList());
    if (results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none)) {
      statusLabel.value = 'Offline';
    } else if (results.contains(ConnectivityResult.wifi)) {
      statusLabel.value = 'Connected (Wi‑Fi)';
    } else if (results.contains(ConnectivityResult.mobile)) {
      statusLabel.value = 'Connected (Mobile)';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      statusLabel.value = 'Connected (Ethernet)';
    } else {
      statusLabel.value = 'Connected';
    }
  }

  Future<void> _loadWifiInfo() async {
    try {
      wifiName.value = await networkInfo.getWifiName() ?? 'Unavailable';
      wifiIP.value = await networkInfo.getWifiIP() ?? 'Unavailable';
      wifiBSSID.value = await networkInfo.getWifiBSSID() ?? 'Unavailable';
      wifiGateway.value =
          await networkInfo.getWifiGatewayIP() ?? 'Unavailable';
    } catch (_) {
      wifiName.value = Platform.isIOS || Platform.isAndroid
          ? 'Permission / unavailable'
          : 'Unavailable on this platform';
      wifiIP.value = '—';
      wifiBSSID.value = '—';
      wifiGateway.value = '—';
    }
  }

  String _labelFor(ConnectivityResult r) {
    switch (r) {
      case ConnectivityResult.wifi:
        return 'Wi‑Fi';
      case ConnectivityResult.mobile:
        return 'Mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.satellite:
        return 'Satellite';
      case ConnectivityResult.none:
        return 'None';
    }
  }
}
