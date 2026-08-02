import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'qr_scanner_controller.dart';

class QrScannerScreen extends GetView<QrScannerController> {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _QrScannerBody(controller: controller);
  }
}

class _QrScannerBody extends StatefulWidget {
  const _QrScannerBody({required this.controller});

  final QrScannerController controller;

  @override
  State<_QrScannerBody> createState() => _QrScannerBodyState();
}

class _QrScannerBodyState extends State<_QrScannerBody> {
  late final MobileScannerController _scanner;

  @override
  void initState() {
    super.initState();
    _scanner = MobileScannerController();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.controller;
    return AppUi.gradientScaffold(
      context: context,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        title: Text('QR Scanner', style: openSansBold.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () async {
              await _scanner.toggleTorch();
              c.toggleTorch();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppUi.radiusMd),
                  child: MobileScanner(
                    controller: _scanner,
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final raw = barcodes.first.rawValue;
                      if (raw != null) c.handleScan(raw);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Paste QR content',
                  filled: true,
                  prefixIcon: const Icon(Icons.qr_code_2_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: c.setManualResult,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: Obx(() {
                final result = c.lastResult.value;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppUi.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Result',
                            style: openSansSemiBold.copyWith(fontSize: 13)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              result.isEmpty ? 'No scan yet' : result,
                              style: openSansRegular.copyWith(
                                fontSize: 14,
                                color: result.isEmpty
                                    ? scheme.onSurface.withValues(alpha: 0.45)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed:
                                    result.isEmpty ? null : c.copyResult,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    result.isEmpty ? null : c.shareResult,
                                icon: const Icon(Icons.share_rounded, size: 18),
                                label: const Text('Share'),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  result.isEmpty ? null : c.clearResult,
                              icon: const Icon(Icons.clear_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
