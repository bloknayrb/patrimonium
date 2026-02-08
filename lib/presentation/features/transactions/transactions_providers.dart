import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';

/// Watch all transactions (most recent first).
final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAllTransactions();
});

/// Watch transactions for a specific account.
final accountTransactionsProvider =
    StreamProvider.family<List<Transaction>, String>((ref, accountId) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionsForAccount(accountId);
});

/// Recent transactions for dashboard (last 10).
final recentTransactionsProvider = FutureProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).getRecentTransactions(limit: 10);
});

/// Total income for current month.
final monthlyIncomeProvider = FutureProvider<int>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  return ref.watch(transactionRepositoryProvider).getTotalIncome(
    start.millisecondsSinceEpoch,
    end.millisecondsSinceEpoch,
  );
});

/// Total expenses for current month.
final monthlyExpensesProvider = FutureProvider<int>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  return ref.watch(transactionRepositoryProvider).getTotalExpenses(
    start.millisecondsSinceEpoch,
    end.millisecondsSinceEpoch,
  );
});

/// Search query state.
final transactionSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered transactions based on search query.
final filteredTransactionsProvider = FutureProvider<List<Transaction>>((ref) {
  final query = ref.watch(transactionSearchQueryProvider);
  if (query.isEmpty) {
    return ref.watch(transactionRepositoryProvider).getAllTransactions();
  }
  return ref.watch(transactionRepositoryProvider).searchByPayee(query);
});

/// Uncategorized transaction count.
final uncategorizedCountProvider = FutureProvider<int>((ref) async {
  final transactions = await ref
      .watch(transactionRepositoryProvider)
      .getUncategorizedTransactions();
  return transactions.length;
});

/// All categories for the category picker.
final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategories();
});

/// Expense categories only.
final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchExpenseCategories();
});

/// Income categories only.
final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchIncomeCategories();
});
