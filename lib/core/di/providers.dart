import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/local/database/app_database.dart';
import '../../data/local/secure_storage/secure_storage_service.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../domain/usecases/auth/biometric_service.dart';
import '../../domain/usecases/auth/pin_service.dart';
import '../../domain/usecases/categories/category_seeder.dart';
import '../../domain/usecases/export/csv_export_service.dart';
import '../../domain/usecases/recurring/recurring_detection_service.dart';
import '../router/app_router.dart';

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

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(databaseProvider));
});

final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepository>((ref) {
  return RecurringTransactionRepository(ref.watch(databaseProvider));
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
// RECURRING DETECTION
// =============================================================================

final recurringDetectionServiceProvider =
    Provider<RecurringDetectionService>((ref) {
  return RecurringDetectionService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(recurringTransactionRepositoryProvider),
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
  return ref.watch(biometricServiceProvider).isEnabled();
});

/// Whether biometric auth is available on this device.
final biometricAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometricServiceProvider).isAvailable();
});

/// Current auto-lock timeout in seconds.
final autoLockTimeoutProvider = FutureProvider<int>((ref) {
  return ref.watch(secureStorageProvider).getAutoLockTimeoutSeconds();
});

// =============================================================================
// APP STATE PROVIDERS
// =============================================================================

/// Provider for the current theme mode.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Provider for the app router (needs Ref for auth redirect logic).
final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter(ref);
});

/// Whether the app is currently unlocked (past the lock screen).
final isUnlockedProvider = StateProvider<bool>((ref) => false);

/// Tracks the last time the app was paused (backgrounded).
final lastPausedAtProvider = StateProvider<DateTime?>((ref) => null);

// =============================================================================
// CATEGORY STREAM PROVIDERS
// =============================================================================

/// All categories (used by category pickers and lookups across features).
final allCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategories();
});

/// Expense categories only.
final expenseCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchExpenseCategories();
});

/// Income categories only.
final incomeCategoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchIncomeCategories();
});
