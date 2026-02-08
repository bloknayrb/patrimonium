import 'package:local_auth/local_auth.dart';

import '../../../data/local/secure_storage/secure_storage_service.dart';

/// Service for biometric authentication using local_auth.
class BiometricService {
  BiometricService(this._storage);

  final SecureStorageService _storage;
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if the device supports biometric authentication.
  Future<bool> isDeviceSupported() => _localAuth.isDeviceSupported();

  /// Check if biometric authentication is available (device supports + enrolled).
  Future<bool> isAvailable() async {
    final isSupported = await _localAuth.isDeviceSupported();
    if (!isSupported) return false;

    final canCheck = await _localAuth.canCheckBiometrics;
    return canCheck;
  }

  /// Get the list of available biometric types.
  Future<List<BiometricType>> getAvailableBiometrics() {
    return _localAuth.getAvailableBiometrics();
  }

  /// Whether the user has enabled biometric auth in settings.
  Future<bool> isEnabled() => _storage.isBiometricEnabled();

  /// Enable or disable biometric authentication.
  Future<void> setEnabled(bool enabled) =>
      _storage.setBiometricEnabled(enabled);

  /// Authenticate the user with biometrics.
  ///
  /// Returns true if authentication was successful.
  Future<bool> authenticate({
    String reason = 'Unlock Patrimonium',
  }) async {
    try {
      final isAvail = await isAvailable();
      if (!isAvail) return false;

      final isEnabled = await _storage.isBiometricEnabled();
      if (!isEnabled) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      // Authentication failed or was cancelled
      return false;
    }
  }
}
