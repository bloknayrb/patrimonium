import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';

/// Watch all visible accounts.
final accountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

/// Watch all accounts including hidden.
final allAccountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccountsIncludingHidden();
});

/// Watch accounts grouped by type.
final accountsByTypeProvider = FutureProvider.autoDispose<Map<String, List<Account>>>((ref) {
  return ref.watch(accountRepositoryProvider).getAccountsByType();
});

/// Watch net worth.
final netWorthProvider = StreamProvider.autoDispose<int>((ref) {
  return ref.watch(accountRepositoryProvider).watchNetWorth();
});

/// Watch total assets.
final totalAssetsProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(accountRepositoryProvider).getTotalAssets();
});

/// Watch total liabilities.
final totalLiabilitiesProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(accountRepositoryProvider).getTotalLiabilities();
});

/// Watch a single account by ID.
final accountByIdProvider = StreamProvider.autoDispose.family<Account?, String>((ref, id) {
  return ref.watch(accountRepositoryProvider).watchAccountById(id);
});

/// Account type metadata for display.
class AccountTypeInfo {
  final String key;
  final String label;
  final String icon;
  final bool isAsset;

  const AccountTypeInfo({
    required this.key,
    required this.label,
    required this.icon,
    required this.isAsset,
  });
}

const accountTypes = [
  AccountTypeInfo(key: 'checking', label: 'Checking', icon: 'account_balance', isAsset: true),
  AccountTypeInfo(key: 'savings', label: 'Savings', icon: 'savings', isAsset: true),
  AccountTypeInfo(key: 'credit_card', label: 'Credit Card', icon: 'credit_card', isAsset: false),
  AccountTypeInfo(key: 'brokerage', label: 'Brokerage', icon: 'trending_up', isAsset: true),
  AccountTypeInfo(key: '401k', label: '401(k)', icon: 'account_balance_wallet', isAsset: true),
  AccountTypeInfo(key: 'ira', label: 'IRA', icon: 'account_balance_wallet', isAsset: true),
  AccountTypeInfo(key: 'roth_ira', label: 'Roth IRA', icon: 'account_balance_wallet', isAsset: true),
  AccountTypeInfo(key: 'hsa', label: 'HSA', icon: 'health_and_safety', isAsset: true),
  AccountTypeInfo(key: 'mortgage', label: 'Mortgage', icon: 'house', isAsset: false),
  AccountTypeInfo(key: 'auto_loan', label: 'Auto Loan', icon: 'directions_car', isAsset: false),
  AccountTypeInfo(key: 'student_loan', label: 'Student Loan', icon: 'school', isAsset: false),
  AccountTypeInfo(key: 'personal_loan', label: 'Personal Loan', icon: 'money', isAsset: false),
  AccountTypeInfo(key: 'line_of_credit', label: 'Line of Credit', icon: 'credit_score', isAsset: false),
  AccountTypeInfo(key: 'real_estate', label: 'Real Estate', icon: 'home_work', isAsset: true),
  AccountTypeInfo(key: 'vehicle', label: 'Vehicle', icon: 'directions_car', isAsset: true),
  AccountTypeInfo(key: 'crypto', label: 'Crypto', icon: 'currency_bitcoin', isAsset: true),
  AccountTypeInfo(key: 'other_asset', label: 'Other Asset', icon: 'category', isAsset: true),
  AccountTypeInfo(key: 'other_liability', label: 'Other Liability', icon: 'money_off', isAsset: false),
];

/// Get display label for an account type key.
String getAccountTypeLabel(String typeKey) {
  return accountTypes
      .where((t) => t.key == typeKey)
      .map((t) => t.label)
      .firstOrNull ?? typeKey;
}

/// Get whether an account type is an asset.
bool isAccountTypeAsset(String typeKey) {
  return accountTypes
      .where((t) => t.key == typeKey)
      .map((t) => t.isAsset)
      .firstOrNull ?? true;
}

/// Account type grouping for display.
const accountTypeGroups = {
  'Cash': ['checking', 'savings'],
  'Credit Cards': ['credit_card', 'line_of_credit'],
  'Investments': ['brokerage', '401k', 'ira', 'roth_ira', 'hsa'],
  'Loans': ['mortgage', 'auto_loan', 'student_loan', 'personal_loan'],
  'Property': ['real_estate', 'vehicle'],
  'Other': ['crypto', 'other_asset', 'other_liability'],
};
