import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'unit_converter_controller.dart';

class UnitConverterScreen extends GetView<UnitConverterController> {
  const UnitConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Get.back(),
        ),
        title: Text('Unit Converter', style: openSansBold.copyWith(fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Category', style: openSansSemiBold.copyWith(fontSize: 12.5)),
          const SizedBox(height: 8),
          Obx(() {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in UnitCategory.values)
                  ChoiceChip(
                    label: Text(_categoryLabel(c)),
                    selected: controller.category.value == c,
                    onSelected: (_) => controller.setCategory(c),
                    selectedColor: AppUi.brandPurple.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: controller.category.value == c
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: controller.category.value == c
                          ? AppUi.brandPurple
                          : scheme.onSurface,
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 20),
          _Card(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From', style: openSansMedium.copyWith(fontSize: 12)),
                const SizedBox(height: 8),
                Obx(
                  () => DropdownButtonFormField<String>(
                    key: ValueKey(
                        'from-${controller.category.value}-${controller.fromUnitId.value}'),
                    initialValue: controller.fromUnitId.value,
                    decoration: _decoration(),
                    items: [
                      for (final u in controller.currentUnits)
                        DropdownMenuItem(value: u.id, child: Text(u.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.setFromUnit(v);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.inputController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true, signed: true),
                  style: openSansBold.copyWith(fontSize: 22),
                  decoration: _decoration().copyWith(
                    labelText: 'Value',
                    labelStyle: const TextStyle(fontSize: 13),
                  ),
                  onChanged: controller.setInput,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: IconButton.filledTonal(
              onPressed: controller.swapUnits,
              icon: const Icon(Icons.swap_vert_rounded),
              tooltip: 'Swap',
            ),
          ),
          const SizedBox(height: 10),
          _Card(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('To', style: openSansMedium.copyWith(fontSize: 12)),
                const SizedBox(height: 8),
                Obx(
                  () => DropdownButtonFormField<String>(
                    key: ValueKey(
                        'to-${controller.category.value}-${controller.toUnitId.value}'),
                    initialValue: controller.toUnitId.value,
                    decoration: _decoration(),
                    items: [
                      for (final u in controller.currentUnits)
                        DropdownMenuItem(value: u.id, child: Text(u.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.setToUnit(v);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppUi.brandPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Result',
                          style: openSansMedium.copyWith(
                            fontSize: 11.5,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.resultText.value,
                          style: openSansBold.copyWith(
                            fontSize: 28,
                            color: AppUi.brandPurple,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.toUnit.label,
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
        ],
      ),
    );
  }

  String _categoryLabel(UnitCategory c) {
    switch (c) {
      case UnitCategory.length:
        return 'Length';
      case UnitCategory.weight:
        return 'Weight';
      case UnitCategory.temperature:
        return 'Temperature';
    }
  }

  InputDecoration _decoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}
