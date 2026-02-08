import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../shared/loading/shimmer_loading.dart';
import '../accounts/accounts_providers.dart';
import '../transactions/add_edit_transaction_screen.dart';
import '../transactions/transactions_providers.dart';

/// Dashboard home screen with financial overview cards.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrimonium'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync accounts',
            onPressed: () {
              // TODO: Trigger bank sync
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Insights',
            onPressed: () {
              // TODO: Open insights screen
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _NetWorthCard(),
          SizedBox(height: 16),
          _CashFlowCard(),
          SizedBox(height: 16),
          _BudgetHealthCard(),
          SizedBox(height: 16),
          _RecentTransactionsCard(),
          SizedBox(height: 16),
          _AiInsightsCard(),
          SizedBox(height: 80), // Space for FAB
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddEditTransactionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),
    );
  }
}

class _NetWorthCard extends ConsumerWidget {
  const _NetWorthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final finance = theme.finance;
    final netWorthAsync = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net Worth',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            netWorthAsync.when(
              data: (nw) => Text(
                nw.toCurrency(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: nw >= 0 ? finance.netWorthPositive : theme.colorScheme.error,
                ),
              ),
              loading: () => Text(
                '...',
                style: theme.textTheme.headlineMedium,
              ),
              error: (_, _) => Text(
                '--',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 4),
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Add accounts to track your net worth',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }
                return Text(
                  '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowCard extends ConsumerWidget {
  const _CashFlowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final finance = theme.finance;
    final incomeAsync = ref.watch(monthlyIncomeProvider);
    final expensesAsync = ref.watch(monthlyExpensesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cash Flow This Month',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Income', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        incomeAsync.when(
                          data: (v) => v.toCurrency(),
                          loading: () => '...',
                          error: (_, _) => '--',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: finance.income,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expenses', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        expensesAsync.when(
                          data: (v) => v.abs().toCurrency(),
                          loading: () => '...',
                          error: (_, _) => '--',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: finance.expense,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Net cash flow
            Builder(
              builder: (context) {
                final income = incomeAsync.valueOrNull ?? 0;
                final expenses = expensesAsync.valueOrNull ?? 0;
                final net = income + expenses; // expenses are negative
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        net.toCurrency(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: net >= 0 ? finance.income : finance.expense,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetHealthCard extends StatelessWidget {
  const _BudgetHealthCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget Health',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Budgets not yet implemented
                  },
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Create your first budget to track spending',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends ConsumerWidget {
  const _RecentTransactionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentAsync = ref.watch(recentTransactionsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Switch to transactions tab (index 2)
                    StatefulNavigationShell.of(context).goBranch(2);
                  },
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            recentAsync.when(
              loading: () => const ShimmerTransactionList(itemCount: 3),
              error: (_, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('Error loading transactions')),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No transactions yet. Add one or connect your bank.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: transactions
                      .take(5)
                      .map((t) => _RecentTransactionItem(transaction: t))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionItem extends StatelessWidget {
  final Transaction transaction;

  const _RecentTransactionItem({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = theme.finance;
    final isIncome = transaction.amountCents > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            size: 16,
            color: isIncome ? finance.income : theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              transaction.payee,
              style: theme.textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            transaction.amountCents.toCurrency(),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isIncome ? finance.income : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiInsightsCard extends StatelessWidget {
  const _AiInsightsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Insights',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Add financial data to get personalized insights',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
