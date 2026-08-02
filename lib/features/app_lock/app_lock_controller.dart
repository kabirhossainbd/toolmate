import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';

class AppLockController extends GetxController {
  static const _boxName = 'app_settings';
  static const _enabledKey = 'app_lock_enabled';
  static const _pinKey = 'app_lock_pin';

  final LocalAuthentication _localAuth = LocalAuthentication();

  late Box _settings;

  final RxBool isEnabled = false.obs;
  final RxBool hasPin = false.obs;
  final RxBool biometricsAvailable = false.obs;
  final RxBool isBusy = false.obs;
  final RxString statusMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    _settings = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);

    isEnabled.value = _settings.get(_enabledKey, defaultValue: false) as bool;
    hasPin.value = (_settings.get(_pinKey) as String?)?.isNotEmpty == true;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      biometricsAvailable.value = canCheck || supported;
    } catch (_) {
      biometricsAvailable.value = false;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value && !hasPin.value) {
      statusMessage.value = 'Set a PIN before enabling app lock';
      Get.snackbar('App Lock', statusMessage.value);
      isEnabled.value = false;
      return;
    }
    isEnabled.value = value;
    await _settings.put(_enabledKey, value);
    statusMessage.value = value ? 'App lock enabled' : 'App lock disabled';
  }

  Future<bool> setPin(String pin, {String? confirm}) async {
    final trimmed = pin.trim();
    if (trimmed.length < 4) {
      statusMessage.value = 'PIN must be at least 4 digits';
      Get.snackbar('App Lock', statusMessage.value);
      return false;
    }
    if (confirm != null && confirm.trim() != trimmed) {
      statusMessage.value = 'PINs do not match';
      Get.snackbar('App Lock', statusMessage.value);
      return false;
    }
    await _settings.put(_pinKey, trimmed);
    hasPin.value = true;
    statusMessage.value = 'PIN saved';
    Get.snackbar('App Lock', statusMessage.value);
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = _settings.get(_pinKey) as String?;
    if (stored == null || stored.isEmpty) return false;
    return pin.trim() == stored;
  }

  /// Prefer biometrics when available; fall back to PIN verification.
  Future<bool> authenticate({String? pin}) async {
    isBusy.value = true;
    statusMessage.value = '';
    try {
      if (biometricsAvailable.value) {
        try {
          final ok = await _localAuth.authenticate(
            localizedReason: 'Unlock Toolmate',
            options: const AuthenticationOptions(
              biometricOnly: false,
              stickyAuth: true,
            ),
          );
          if (ok) {
            statusMessage.value = 'Unlocked with biometrics';
            return true;
          }
        } catch (_) {
          // Fall through to PIN.
        }
      }

      if (pin == null || pin.isEmpty) {
        statusMessage.value = biometricsAvailable.value
            ? 'Biometrics cancelled — enter PIN'
            : 'Enter PIN to unlock';
        return false;
      }

      final ok = await verifyPin(pin);
      statusMessage.value = ok ? 'Unlocked with PIN' : 'Incorrect PIN';
      return ok;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> testUnlock({String? pin}) async {
    final ok = await authenticate(pin: pin);
    Get.snackbar('App Lock', ok ? 'Unlock successful' : statusMessage.value);
  }
}
