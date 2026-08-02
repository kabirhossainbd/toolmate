import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'currency_converter_controller.dart';

class CurrencyConverterScreen extends GetView<CurrencyConverterController> {
  const CurrencyConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final codes = CurrencyConverterController.currencies;
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        title: Text('Currency Converter',
            style: openSansBold.copyWith(fontSize: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Offline approximate rates vs USD',
              style: openSansMedium.copyWith(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text('From', style: openSansSemiBold.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Obx(
              () => DropdownButtonFormField<String>(
                key: ValueKey('from-${controller.fromCurrency.value}'),
                initialValue: controller.fromCurrency.value,
                decoration: _dec(),
                items: [
                  for (final c in codes)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  if (v != null) controller.setFrom(v);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _dec().copyWith(labelText: 'Amount'),
              controller: controller.amountController,
              onChanged: controller.setAmount,
            ),
            const SizedBox(height: 12),
            Center(
              child: IconButton.filledTonal(
                onPressed: controller.swap,
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Text('To', style: openSansSemiBold.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Obx(
              () => DropdownButtonFormField<String>(
                key: ValueKey('to-${controller.toCurrency.value}'),
                initialValue: controller.toCurrency.value,
                decoration: _dec(),
                items: [
                  for (final c in codes)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  if (v != null) controller.setTo(v);
                },
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppUi.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Converted',
                      style: openSansMedium.copyWith(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${controller.resultText.value} ${controller.toCurrency.value}',
                      style: openSansBold.copyWith(
                        fontSize: 26,
                        color: AppUi.brandTeal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1 ${controller.fromCurrency.value} ≈ '
                      '${controller.rateLabel().toStringAsFixed(4)} '
                      '${controller.toCurrency.value}',
                      style: openSansRegular.copyWith(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec() => InputDecoration(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          borderSide: BorderSide.none,
        ),
      );
}
