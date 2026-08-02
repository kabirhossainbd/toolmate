import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CurrencyConverterController extends GetxController {
  /// Approximate rates: 1 USD = value in currency (offline).
  static const Map<String, double> ratesVsUsd = {
    'USD': 1.0,
    'BDT': 117.0,
    'INR': 83.5,
    'EUR': 0.92,
    'GBP': 0.79,
    'SAR': 3.75,
  };

  static const List<String> currencies = [
    'USD',
    'BDT',
    'INR',
    'EUR',
    'GBP',
    'SAR',
  ];

  final fromCurrency = 'USD'.obs;
  final toCurrency = 'BDT'.obs;
  final resultText = '117'.obs;
  late final TextEditingController amountController;

  @override
  void onInit() {
    super.onInit();
    amountController = TextEditingController(text: '1');
    convert();
  }

  @override
  void onClose() {
    amountController.dispose();
    super.onClose();
  }

  void setFrom(String code) {
    fromCurrency.value = code;
    convert();
  }

  void setTo(String code) {
    toCurrency.value = code;
    convert();
  }

  void setAmount(String text) => convert();

  void swap() {
    final a = fromCurrency.value;
    fromCurrency.value = toCurrency.value;
    toCurrency.value = a;
    convert();
  }

  void convert() {
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) {
      resultText.value = '—';
      return;
    }
    final fromRate = ratesVsUsd[fromCurrency.value] ?? 1;
    final toRate = ratesVsUsd[toCurrency.value] ?? 1;
    final usd = amount / fromRate;
    final out = usd * toRate;
    resultText.value = _format(out);
  }

  double rateLabel() {
    final fromRate = ratesVsUsd[fromCurrency.value] ?? 1;
    final toRate = ratesVsUsd[toCurrency.value] ?? 1;
    return toRate / fromRate;
  }

  String _format(double v) {
    if (v.abs() >= 1e6) return v.toStringAsExponential(4);
    if (v.abs() >= 100) return v.toStringAsFixed(2);
    if (v.abs() >= 1) return v.toStringAsFixed(4);
    return v.toStringAsFixed(6);
  }
}
