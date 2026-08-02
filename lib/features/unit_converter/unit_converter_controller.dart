import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum UnitCategory { length, weight, temperature }

class UnitDef {
  final String id;
  final String label;
  final double toBase;
  final double Function(double)? fromBaseOverride;
  final double Function(double)? toBaseOverride;

  const UnitDef({
    required this.id,
    required this.label,
    this.toBase = 1,
    this.fromBaseOverride,
    this.toBaseOverride,
  });

  double toBaseValue(double v) =>
      toBaseOverride != null ? toBaseOverride!(v) : v * toBase;

  double fromBaseValue(double base) =>
      fromBaseOverride != null ? fromBaseOverride!(base) : base / toBase;
}

class UnitConverterController extends GetxController {
  static final Map<UnitCategory, List<UnitDef>> units = {
    UnitCategory.length: const [
      UnitDef(id: 'm', label: 'Meter (m)', toBase: 1),
      UnitDef(id: 'km', label: 'Kilometer (km)', toBase: 1000),
      UnitDef(id: 'cm', label: 'Centimeter (cm)', toBase: 0.01),
      UnitDef(id: 'mm', label: 'Millimeter (mm)', toBase: 0.001),
      UnitDef(id: 'mi', label: 'Mile (mi)', toBase: 1609.344),
      UnitDef(id: 'yd', label: 'Yard (yd)', toBase: 0.9144),
      UnitDef(id: 'ft', label: 'Foot (ft)', toBase: 0.3048),
      UnitDef(id: 'in', label: 'Inch (in)', toBase: 0.0254),
    ],
    UnitCategory.weight: const [
      UnitDef(id: 'kg', label: 'Kilogram (kg)', toBase: 1),
      UnitDef(id: 'g', label: 'Gram (g)', toBase: 0.001),
      UnitDef(id: 'mg', label: 'Milligram (mg)', toBase: 0.000001),
      UnitDef(id: 'lb', label: 'Pound (lb)', toBase: 0.45359237),
      UnitDef(id: 'oz', label: 'Ounce (oz)', toBase: 0.028349523125),
      UnitDef(id: 't', label: 'Metric ton (t)', toBase: 1000),
    ],
    UnitCategory.temperature: [
      UnitDef(
        id: 'c',
        label: 'Celsius (°C)',
        toBaseOverride: (v) => v,
        fromBaseOverride: (b) => b,
      ),
      UnitDef(
        id: 'f',
        label: 'Fahrenheit (°F)',
        toBaseOverride: (v) => (v - 32) * 5 / 9,
        fromBaseOverride: (b) => b * 9 / 5 + 32,
      ),
      UnitDef(
        id: 'k',
        label: 'Kelvin (K)',
        toBaseOverride: (v) => v - 273.15,
        fromBaseOverride: (b) => b + 273.15,
      ),
    ],
  };

  final category = UnitCategory.length.obs;
  final fromUnitId = 'm'.obs;
  final toUnitId = 'km'.obs;
  final resultText = '0.001'.obs;
  late final TextEditingController inputController;

  List<UnitDef> get currentUnits => units[category.value]!;

  UnitDef get fromUnit =>
      currentUnits.firstWhere((u) => u.id == fromUnitId.value);

  UnitDef get toUnit =>
      currentUnits.firstWhere((u) => u.id == toUnitId.value);

  @override
  void onInit() {
    super.onInit();
    inputController = TextEditingController(text: '1');
    convert();
  }

  @override
  void onClose() {
    inputController.dispose();
    super.onClose();
  }

  void setCategory(UnitCategory c) {
    category.value = c;
    final list = units[c]!;
    fromUnitId.value = list.first.id;
    toUnitId.value = list.length > 1 ? list[1].id : list.first.id;
    convert();
  }

  void setFromUnit(String id) {
    fromUnitId.value = id;
    convert();
  }

  void setToUnit(String id) {
    toUnitId.value = id;
    convert();
  }

  void setInput(String text) => convert();

  void swapUnits() {
    final a = fromUnitId.value;
    fromUnitId.value = toUnitId.value;
    toUnitId.value = a;
    convert();
  }

  void convert() {
    final raw = double.tryParse(inputController.text.trim());
    if (raw == null) {
      resultText.value = '—';
      return;
    }
    final base = fromUnit.toBaseValue(raw);
    final out = toUnit.fromBaseValue(base);
    resultText.value = _format(out);
  }

  String _format(double v) {
    if (v.abs() >= 1e6 || (v.abs() > 0 && v.abs() < 1e-4)) {
      return v.toStringAsExponential(4);
    }
    final s = v.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
