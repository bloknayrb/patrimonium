---
name: flutter-security-patterns
description: Security best practices for Flutter apps. Covers secure storage, API security, authentication, data protection, and common vulnerability prevention.
---

# Flutter Security Patterns

Production-ready security patterns for the Patrimonium personal finance app.

**Note**: This project already uses PBKDF2-HMAC-SHA256 for PIN hashing and `flutter_secure_storage` via `SecureStorageService`. These patterns complement the existing architecture.

## Secure Storage

### Never Store Sensitive Data in Plain Text

```dart
// NEVER DO THIS
await prefs.setString('password', 'user_password');
await prefs.setString('api_token', 'secret_token');

// USE SecureStorageService (project wrapper around flutter_secure_storage)
await secureStorage.write('auth_token', token);
final token = await secureStorage.read('auth_token');
await secureStorage.delete('auth_token');
```

## API Security

### HTTPS Only

```dart
// NEVER use HTTP in production
// ALWAYS use HTTPS
final dio = Dio(BaseOptions(
  baseUrl: 'https://api.example.com',
));
```

### Certificate Pinning (for sensitive financial APIs)

```dart
(dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
  client.badCertificateCallback = (cert, host, port) {
    final certSha256 = sha256.convert(cert.der).toString();
    const expectedHash = 'YOUR_CERTIFICATE_SHA256_HASH';
    return certSha256 == expectedHash;
  };
  return client;
};
```

## Secure Token Management

```dart
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read('auth_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Attempt token refresh, then retry
    }
    handler.next(err);
  }
}
```

## Input Validation

```dart
class InputValidator {
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  static bool isValidAmount(String amount) {
    final parsed = double.tryParse(amount);
    return parsed != null && parsed >= 0 && parsed < 100000000; // Max $1M
  }

  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
```

## Android Platform Security

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<application
  android:usesCleartextTraffic="false"
  android:networkSecurityConfig="@xml/network_security_config">
</application>
```

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">yourdomain.com</domain>
  </domain-config>
</network-security-config>
```

## Code Obfuscation

```bash
# Build with obfuscation (always for release)
flutter build apk --release --obfuscate --split-debug-info=./debug-info
flutter build appbundle --release --obfuscate --split-debug-info=./debug-info
```

## Logging Safety

```dart
// NEVER log sensitive data
logger.d('User password: $password'); // NEVER!
logger.d('API token: $token'); // NEVER!

// Guard debug output
if (kDebugMode) {
  print('Debug: $debugInfo');
}
```

## Database Security

Drift uses parameterized queries by default. **Never** use string interpolation in custom SQL:

```dart
// NEVER DO THIS
db.customSelect('SELECT * FROM users WHERE id = $id');

// GOOD — Drift's query builder is safe
(select(accounts)..where((a) => a.id.equals(id))).getSingle();
```

## Pre-Release Security Checklist

- [ ] All secrets in `flutter_secure_storage` (not SharedPreferences)
- [ ] HTTPS only for all network requests
- [ ] API tokens refreshed automatically on 401
- [ ] No hardcoded API keys in source — use `SecureStorageService`
- [ ] `print()` calls guarded by `kDebugMode`
- [ ] Code obfuscation enabled (`--obfuscate`)
- [ ] `android:usesCleartextTraffic="false"` in AndroidManifest.xml
- [ ] Input validation on all user-facing forms
- [ ] Drift parameterized queries (never string interpolation in SQL)
- [ ] No sensitive data in logs
- [ ] `key.properties` in `.gitignore`
- [ ] Dependency vulnerabilities checked

## Common Vulnerabilities to Avoid

```dart
// 1. Hardcoded secrets
const apiKey = 'abc123'; // NEVER!

// 2. Plain text storage
prefs.setString('password', 'secret'); // NEVER!

// 3. HTTP in production
final url = 'http://api.example.com'; // NEVER!

// 4. SQL injection
db.customSelect('SELECT * FROM users WHERE id = $id'); // Use parameterized!

// 5. Logging sensitive data
print('Password: $password'); // NEVER!

// 6. Weak hashing
final hash = md5.convert(password.codeUnits); // Use PBKDF2!
```

---

*Security patterns adapted from [flutter-claude-code](https://github.com/cleydson/flutter-claude-code) by @cleydson.*
