import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/models.dart';
import '../../../domain/usecases/budgets/budget_spending_service.dart';

export '../../../domain/usecases/budgets/budget_spending_service.dart'
    show BudgetWithSpent;

/// Watch all active budgets.
final budgetsProvider = StreamProvider.autoDispose<List<Budget>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchActiveBudgets();
});

/// Get a single budget by ID.
final budgetByIdProvider =
    FutureProvider.autoDispose.family<Budget?, String>((ref, id) {
  return ref.watch(budgetRepositoryProvider).getBudgetById(id);
});

/// Budgets with their current-period spending amounts.
final budgetsWithSpentProvider =
    FutureProvider.autoDispose<List<BudgetWithSpent>>((ref) async {
  final budgets = await ref.watch(budgetsProvider.future);
  final service = ref.watch(budgetSpendingServiceProvider);
  return service.getBudgetsWithSpending(budgets);
});
