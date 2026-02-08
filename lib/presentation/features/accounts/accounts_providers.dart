import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';

// Re-export account type constants so existing imports continue to work.
export '../../../core/constants/account_types.dart';

/// Watch all visible accounts.
final accountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

/// Watch all accounts including hidden.
final allAccountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccountsIncludingHidden();
});

/// Watch accounts grouped by type (reactive via stream).
final accountsByTypeProvider = StreamProvider.autoDispose<Map<String, List<Account>>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts().map((accounts) {
    final grouped = <String, List<Account>>{};
    for (final account in accounts) {
      grouped.putIfAbsent(account.accountType, () => []).add(account);
    }
    return grouped;
  });
});

/// Watch net worth.
final netWorthProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(accountRepositoryProvider).watchNetWorth();
});

/// Watch total assets (reactive via stream).
final totalAssetsProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts().map((accounts) {
    return accounts.where((a) => a.isAsset).fold<int>(0, (sum, a) => sum + a.balanceCents);
  });
});

/// Watch total liabilities (reactive via stream).
final totalLiabilitiesProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts().map((accounts) {
    return accounts.where((a) => !a.isAsset).fold<int>(0, (sum, a) => sum + a.balanceCents);
  });
});

/// Watch a single account by ID.
final accountByIdProvider = StreamProvider.autoDispose.family<Account?, String>((ref, id) {
  return ref.watch(accountRepositoryProvider).watchAccountById(id);
});
