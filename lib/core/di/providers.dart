import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database/app_database.dart';
import '../../data/local/secure_storage/secure_storage_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../domain/usecases/auth/biometric_service.dart';
import '../../domain/usecases/auth/pin_service.dart';
import '../../domain/usecases/categories/category_seeder.dart';
import '../../domain/usecases/export/csv_export_service.dart';

// =============================================================================
// INFRASTRUCTURE PROVIDERS
// =============================================================================

/// Provides the singleton database instance.
///
/// Initialized asynchronously at app start and overridden in ProviderScope.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden with an initialized AppDatabase '
    'in the root ProviderScope.',
  );
});

/// Provides the secure storage service.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// =============================================================================
// REPOSITORY PROVIDERS
// =============================================================================

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});

// =============================================================================
// EXPORT
// =============================================================================

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return CsvExportService(
    accountRepo: ref.watch(accountRepositoryProvider),
    transactionRepo: ref.watch(transactionRepositoryProvider),
    categoryRepo: ref.watch(categoryRepositoryProvider),
  );
});

// =============================================================================
// CATEGORY SEEDING
// =============================================================================

final categorySeederProvider = Provider<CategorySeeder>((ref) {
  return CategorySeeder(ref.watch(categoryRepositoryProvider));
});

// =============================================================================
// AUTH PROVIDERS
// =============================================================================

final pinServiceProvider = Provider<PinService>((ref) {
  return PinService(ref.watch(secureStorageProvider));
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService(ref.watch(secureStorageProvider));
});

/// Whether the user has set up a PIN.
final hasPinProvider = FutureProvider<bool>((ref) {
  return ref.watch(pinServiceProvider).hasPin();
});

/// Whether biometric auth is enabled in settings.
final biometricEnabledProvider = FutureProvider<bool>((ref) {
  return ref.watch(pinServiceProvider).isBiometricEnabled();
});

/// Whether biometric auth is available on this device.
final biometricAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricServiceProvider).isAvailable();
});

/// Current auto-lock timeout in seconds.
final autoLockTimeoutProvider = FutureProvider<int>((ref) {
  return ref.watch(secureStorageProvider).getAutoLockTimeoutSeconds();
});
