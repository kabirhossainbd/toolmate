import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'clipboard_item.dart';

class ClipboardController extends GetxController {
  static const _boxName = 'clipboard_history';
  static const _maxItems = 100;

  late Box _box;
  Timer? _pollTimer;
  String? _lastSeen;

  final items = <ClipboardItem>[].obs;
  final isReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> _init() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    _reload();
    isReady.value = true;
    await captureClipboard();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => captureClipboard(),
    );
  }

  void _reload() {
    final list = _box.values
        .whereType<Map>()
        .map((e) => ClipboardItem.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    items.assignAll(list);
    if (list.isNotEmpty) _lastSeen = list.first.text;
  }

  Future<void> captureClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return;
      if (text == _lastSeen) return;
      _lastSeen = text;

      // Skip if newest item already matches.
      if (items.isNotEmpty && items.first.text == text) return;

      final item = ClipboardItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        createdAt: DateTime.now(),
      );
      await _box.put(item.id, item.toMap());
      await _trim();
      _reload();
    } catch (_) {
      // Clipboard may be unavailable on some platforms.
    }
  }

  Future<void> _trim() async {
    if (_box.length <= _maxItems) return;
    final sorted = _box.values
        .whereType<Map>()
        .map((e) => ClipboardItem.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final old in sorted.skip(_maxItems)) {
      await _box.delete(old.id);
    }
  }

  Future<void> copyAgain(ClipboardItem item) async {
    await Clipboard.setData(ClipboardData(text: item.text));
    _lastSeen = item.text;
    Get.snackbar(
      'Copied',
      'Text copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
    );
  }

  Future<void> deleteItem(String id) async {
    await _box.delete(id);
    _reload();
  }

  Future<void> clearAll() async {
    await _box.clear();
    _lastSeen = null;
    items.clear();
  }
}
