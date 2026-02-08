import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../data/local/secure_storage/secure_storage_service.dart';

/// Service for PIN hashing, verification, and lockout management.
///
/// Uses PBKDF2-HMAC-SHA256 with 256,000 iterations for key derivation.
class PinService {
  PinService(this._storage);

  final SecureStorageService _storage;

  static const int _iterations = 256000;
  static const int _keyLength = 32; // 256 bits
  static const int _saltLength = 32; // 256 bits

  // ─── PIN Management ───────────────────────────────────────────────

  /// Check if a PIN has been set up.
  Future<bool> hasPin() => _storage.hasPin();

  /// Set up a new PIN. Hashes with PBKDF2 and stores hash + salt.
  Future<void> setupPin(String pin) async {
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.setPinHash(
      base64.encode(hash),
      base64.encode(salt),
    );
  }

  /// Verify a PIN against the stored hash.
  /// Returns true if the PIN is correct.
  Future<bool> verifyPin(String pin) async {
    final storedHashBase64 = await _storage.getPinHash();
    final storedSaltBase64 = await _storage.getPinSalt();

    if (storedHashBase64 == null || storedSaltBase64 == null) {
      return false;
    }

    final storedHash = base64.decode(storedHashBase64);
    final salt = base64.decode(storedSaltBase64);
    final computedHash = _hashPin(pin, salt);

    return _constantTimeEquals(storedHash, computedHash);
  }

  /// Change the PIN. Requires verifying the old PIN first.
  Future<bool> changePin(String oldPin, String newPin) async {
    final isOldValid = await verifyPin(oldPin);
    if (!isOldValid) return false;

    await setupPin(newPin);
    return true;
  }

  /// Remove PIN (used for reset).
  Future<void> clearPin() => _storage.clearPin();

  // ─── Biometric ────────────────────────────────────────────────────

  /// Check if biometric auth is enabled.
  Future<bool> isBiometricEnabled() => _storage.isBiometricEnabled();

  /// Enable or disable biometric authentication.
  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.setBiometricEnabled(enabled);

  // ─── PBKDF2 Implementation ────────────────────────────────────────

  /// Generate a cryptographically secure random salt.
  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  /// Hash a PIN using PBKDF2-HMAC-SHA256.
  Uint8List _hashPin(String pin, Uint8List salt) {
    final key = utf8.encode(pin);
    return _pbkdf2(key, salt, _iterations, _keyLength);
  }

  /// PBKDF2 key derivation using HMAC-SHA256.
  Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmacSha256 = Hmac(sha256, password);
    final blocks = (keyLength / 32).ceil(); // SHA256 = 32 bytes
    final result = BytesBuilder();

    for (var i = 1; i <= blocks; i++) {
      final blockBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, i, Endian.big);
      final saltPlusBlock = Uint8List.fromList([...salt, ...blockBytes]);

      var u = hmacSha256.convert(saltPlusBlock).bytes;
      var xor = Uint8List.fromList(u);

      for (var j = 1; j < iterations; j++) {
        u = hmacSha256.convert(u).bytes;
        for (var k = 0; k < xor.length; k++) {
          xor[k] ^= u[k];
        }
      }

      result.add(xor);
    }

    return Uint8List.fromList(result.toBytes().sublist(0, keyLength));
  }

  /// Constant-time comparison to prevent timing attacks.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}
