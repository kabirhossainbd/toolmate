import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

class QrScannerController extends GetxController {
  final lastResult = ''.obs;
  final torchOn = false.obs;

  void handleScan(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    if (value == lastResult.value) return;
    lastResult.value = value;
  }

  void setManualResult(String text) {
    lastResult.value = text.trim();
  }

  Future<void> copyResult() async {
    final text = lastResult.value;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'QR content copied',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
    );
  }

  Future<void> shareResult() async {
    final text = lastResult.value;
    if (text.isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void clearResult() => lastResult.value = '';

  void toggleTorch() => torchOn.value = !torchOn.value;
}
