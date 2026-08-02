import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'app_lock_controller.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _testPinCtrl = TextEditingController();

  late final AppLockController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<AppLockController>();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    _testPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        title: Text('App Lock', style: openSansBold.copyWith(fontSize: 18)),
      ),
      body: SafeArea(
        child: Obx(() {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppUi.accentGradient(AppUi.brandDeep),
                  borderRadius: BorderRadius.circular(AppUi.radiusLg),
                  boxShadow: AppUi.softGlow(AppUi.brandDeep),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Protect Toolmate',
                            style: openSansBold.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.biometricsAvailable.value
                                ? 'Biometrics available — used when possible'
                                : 'PIN authentication only on this device',
                            style: openSansRegular.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Material(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppUi.radiusMd),
                child: SwitchListTile(
                  title: Text('Enable app lock', style: openSansSemiBold),
                  subtitle: Text(
                    controller.hasPin.value
                        ? 'Require unlock when opening the app'
                        : 'Set a PIN first',
                    style: openSansRegular.copyWith(fontSize: 13),
                  ),
                  value: controller.isEnabled.value,
                  onChanged: controller.setEnabled,
                ),
              ),
              const SizedBox(height: 16),
              Text('Set PIN', style: openSansBold.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'New PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  await controller.setPin(
                    _pinCtrl.text,
                    confirm: _confirmCtrl.text,
                  );
                  _pinCtrl.clear();
                  _confirmCtrl.clear();
                },
                child: const Text('Save PIN'),
              ),
              const SizedBox(height: 28),
              Text('Test unlock', style: openSansBold.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                'Tries biometrics first when available, otherwise uses the PIN below.',
                style: openSansRegular.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _testPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN (fallback)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : () => controller.testUnlock(pin: _testPinCtrl.text),
                icon: controller.isBusy.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: const Text('Test unlock'),
              ),
              if (controller.statusMessage.value.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  controller.statusMessage.value,
                  style: openSansMedium.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}
