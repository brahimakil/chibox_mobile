import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';

class SecurityService extends ChangeNotifier {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _pinKey = 'user_pin';
  static const String _biometricsEnabledKey = 'biometrics_enabled';
  static const String _lockTimeoutKey = 'lock_timeout';
  static const String _lastActiveKey = 'last_active_time';

  bool _hasPin = false;
  bool _isBiometricsEnabled = false;
  bool _canCheckBiometrics = false;
  bool _isSessionActive = false;
  int _lockTimeout = 0; // 0 = instantly, -1 = off

  bool get hasPin => _hasPin;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get canCheckBiometrics => _canCheckBiometrics;
  bool get isSessionActive => _isSessionActive;
  int get lockTimeout => _lockTimeout;

  void setSessionActive(bool active) {
    _isSessionActive = active;
    // No need to notify listeners for this internal state usually, 
    // but maybe useful if UI depends on it.
  }

  Future<void> setLastActiveTime() async {
    try {
      await _storage.write(
        key: _lastActiveKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
    }
  }

  Future<DateTime?> getLastActiveTime() async {
    try {
      final timeStr = await _storage.read(key: _lastActiveKey);
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
    } catch (e) {
    }
    return null;
  }

  Future<void> init() async {
    await _checkPinStatus();
    await _checkBiometricsStatus();
    await _checkBiometricsAvailability();
    await _checkLockTimeout();
  }

  Future<void> _checkPinStatus() async {
    final pin = await _storage.read(key: _pinKey);
    _hasPin = pin != null;
    notifyListeners();
  }

  Future<void> _checkBiometricsStatus() async {
    final enabled = await _storage.read(key: _biometricsEnabledKey);
    _isBiometricsEnabled = enabled == 'true';
    notifyListeners();
  }

  Future<void> _checkLockTimeout() async {
    final timeout = await _storage.read(key: _lockTimeoutKey);
    _lockTimeout = timeout != null ? int.parse(timeout) : 0;
    notifyListeners();
  }

  Future<void> setLockTimeout(int seconds) async {
    try {
      await _storage.write(key: _lockTimeoutKey, value: seconds.toString());
      _lockTimeout = seconds;
      notifyListeners();
    } catch (e) {
    }
  }

  Future<void> _checkBiometricsAvailability() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      _canCheckBiometrics = canAuthenticate;
    } on PlatformException catch (e) {
      _canCheckBiometrics = false;
    }
    notifyListeners();
  }

  Future<bool> setPin(String pin) async {
    try {
      await _storage.write(key: _pinKey, value: pin);
      _hasPin = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final storedPin = await _storage.read(key: _pinKey);
      return storedPin == pin;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removePin() async {
    try {
      await _storage.delete(key: _pinKey);
      await _storage.delete(key: _biometricsEnabledKey); // Disable biometrics if PIN is removed
      _hasPin = false;
      _isBiometricsEnabled = false;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setBiometricsEnabled(bool enabled) async {
    if (enabled && !_hasPin) {
      return false; // Cannot enable biometrics without PIN
    }

    try {
      if (enabled) {
        // Verify biometrics before enabling
        final authenticated = await authenticateWithBiometrics();
        if (!authenticated) return false;
      }

      await _storage.write(key: _biometricsEnabledKey, value: enabled.toString());
      _isBiometricsEnabled = enabled;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!_canCheckBiometrics) return false;

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      return false;
    }
  }
}
