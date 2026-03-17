import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/analytics/analytics_providers.dart';
import '../../features/budgets/budgets_providers.dart';
import '../../features/dashboard/dashboard_providers.dart';
import '../../features/transactions/transactions_providers.dart';

/// Invalidates all financial data providers after a sync operation.
///
/// Used by dashboard and connection detail screens to refresh cached
/// FutureProviders after bank sync completes.
void invalidateFinancialData(WidgetRef ref) {
  ref.invalidate(monthlyIncomeProvider);
  ref.invalidate(monthlyExpensesProvider);
  ref.invalidate(spendingByCategoryProvider);
  ref.invalidate(monthlySpendingHistoryProvider);
  ref.invalidate(netWorthHistoryProvider);
  ref.invalidate(uncategorizedCountProvider);
  ref.invalidate(budgetsWithSpentProvider);
  ref.invalidate(monthlyCashFlowProvider);
}
