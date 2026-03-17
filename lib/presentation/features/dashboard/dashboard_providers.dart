import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/models.dart';
import '../../../domain/usecases/analytics/spending_analytics_service.dart';
import '../recurring/recurring_providers.dart';
import '../goals/goals_providers.dart';
import '../transactions/transactions_providers.dart';
import 'dashboard_card_registry.dart';

export '../../../domain/usecases/analytics/analytics_models.dart';

// =============================================================================
// DASHBOARD LAYOUT CONFIG
// =============================================================================

/// User's persisted dashboard layout. Merged with registry on load.
final dashboardLayoutProvider =
    FutureProvider.autoDispose<List<DashboardCardConfig>>((ref) async {
  final repo = ref.watch(dashboardLayoutRepositoryProvider);
  return repo.getLayout();
});

/// Whether dashboard is in edit mode.
final dashboardEditModeProvider = StateProvider<bool>((ref) => false);

// =============================================================================
// CARD CONDITION PROVIDERS
// =============================================================================

/// Single stream for all accounts — condition providers derive from this.
final _allAccountsStreamProvider =
    StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts();
});

/// Set of account types the user has (consolidated from single stream).
final accountTypesProvider = Provider.autoDispose<Set<String>>((ref) {
  final accountsAsync = ref.watch(_allAccountsStreamProvider);
  return accountsAsync.valueOrNull
          ?.map((a) => a.accountType)
          .toSet() ??
      {};
});

const _investmentTypes = {'brokerage', '401k', 'ira', 'roth_ira', 'crypto'};
const _retirementTypes = {'401k', 'ira', 'roth_ira', 'hsa'};

/// Condition: user has investment accounts.
final hasInvestmentAccountsProvider = Provider.autoDispose<bool>((ref) {
  final types = ref.watch(accountTypesProvider);
  return types.any(_investmentTypes.contains);
});

/// Condition: user has mortgage accounts.
final hasMortgageAccountsProvider = Provider.autoDispose<bool>((ref) {
  final types = ref.watch(accountTypesProvider);
  return types.contains('mortgage');
});

/// Condition: user has retirement accounts.
final hasRetirementAccountsProvider = Provider.autoDispose<bool>((ref) {
  final types = ref.watch(accountTypesProvider);
  return types.any(_retirementTypes.contains);
});

/// Condition: user has upcoming bills within 7 days.
final hasUpcomingBillsProvider = Provider.autoDispose<bool>((ref) {
  final recurring = ref.watch(recurringTransactionsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final weekAhead = now.add(const Duration(days: 7));
  return recurring.any((r) {
    final next = DateTime.fromMillisecondsSinceEpoch(r.nextExpectedDate);
    return !next.isBefore(now) && next.isBefore(weekAhead);
  });
});

/// Condition: user has active goals.
final hasGoalsProvider = Provider.autoDispose<bool>((ref) {
  final goals = ref.watch(goalsProvider).valueOrNull ?? [];
  return goals.isNotEmpty;
});

/// Condition: user has uncategorized transactions.
final hasUncategorizedProvider = Provider.autoDispose<bool>((ref) {
  final count = ref.watch(uncategorizedCountProvider).valueOrNull ?? 0;
  return count > 0;
});

/// Condition: user has recurring subscriptions.
final hasSubscriptionsProvider = Provider.autoDispose<bool>((ref) {
  final recurring = ref.watch(recurringTransactionsProvider).valueOrNull ?? [];
  return recurring.any((r) => r.isSubscription);
});

// =============================================================================
// UNREAD INSIGHTS COUNT (Phase B: Smart Alerts)
// =============================================================================

/// Count of unread, active insights for badge display.
final unreadInsightsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final repo = ref.watch(insightRepositoryProvider);
  return repo.watchUnreadInsights().map((list) => list.length);
});

// =============================================================================
// SPENDING HISTORY (Feature #34)
// =============================================================================

/// Monthly spending totals for the last 6 months.
final monthlySpendingHistoryProvider =
    FutureProvider.autoDispose<List<MonthlySpending>>((ref) async {
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final totals = await transactionRepo.getMonthlyExpenseTotals(6);
  return totals
      .map((t) => MonthlySpending(month: t.month, expenseCents: t.expenseCents))
      .toList();
});

// =============================================================================
// SPENDING BY CATEGORY (Feature #34)
// =============================================================================

/// Top 8 spending categories for the current month.
final spendingByCategoryProvider =
    FutureProvider.autoDispose<List<CategorySpending>>((ref) async {
  final service = ref.watch(spendingAnalyticsServiceProvider);
  return service.getTopCategorySpending(8);
});

// =============================================================================
// NET WORTH HISTORY (Feature #35)
// =============================================================================

/// Net worth at each month-end for the last 6 months.
final netWorthHistoryProvider =
    FutureProvider.autoDispose<List<NetWorthSnapshot>>((ref) async {
  final service = ref.watch(spendingAnalyticsServiceProvider);
  return service.getNetWorthHistory(6);
});

// =============================================================================
// ACCOUNT TYPE FILTERED PROVIDERS (used by card widgets)
// =============================================================================

/// Investment accounts for the investments card widget.
final investmentAccountsProvider =
    Provider.autoDispose<AsyncValue<List<Account>>>((ref) {
  return ref.watch(_allAccountsStreamProvider).whenData(
    (accounts) => accounts
        .where((a) => _investmentTypes.contains(a.accountType))
        .toList(),
  );
});

/// Mortgage accounts for the mortgage card widget.
final mortgageAccountsProvider =
    Provider.autoDispose<AsyncValue<List<Account>>>((ref) {
  return ref.watch(_allAccountsStreamProvider).whenData(
    (accounts) =>
        accounts.where((a) => a.accountType == 'mortgage').toList(),
  );
});

/// Retirement accounts for the retirement card widget.
final retirementAccountsProvider =
    Provider.autoDispose<AsyncValue<List<Account>>>((ref) {
  return ref.watch(_allAccountsStreamProvider).whenData(
    (accounts) => accounts
        .where((a) => _retirementTypes.contains(a.accountType))
        .toList(),
  );
});
