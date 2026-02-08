import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/money_extensions.dart';
import '../../../data/local/database/app_database.dart';
import '../../shared/empty_states/empty_state_widget.dart';
import 'add_edit_transaction_screen.dart';
import 'transactions_providers.dart';

/// Transaction list screen with search and filters.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  ref.read(transactionSearchQueryProvider.notifier).state = value;
                },
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(transactionSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.receipt_long,
              title: 'No transactions yet',
              description:
                  'Your transactions will appear here once you add them manually or connect your bank.',
              actionLabel: 'Add Transaction',
              onAction: () => _navigateToAddTransaction(context),
            );
          }
          return _TransactionListView(transactions: transactions);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTransaction(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToAddTransaction(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddEditTransactionScreen(),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const _FilterBottomSheet(),
    );
  }
}

/// Transaction list grouped by date.
class _TransactionListView extends StatelessWidget {
  final List<Transaction> transactions;

  const _TransactionListView({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Group transactions by date
    final grouped = _groupByDate(transactions);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(date: entry.key),
            for (final transaction in entry.value)
              _TransactionTile(transaction: transaction),
          ],
        );
      },
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final groups = <String, List<Transaction>>{};
    for (final t in transactions) {
      final date = t.date.toDateTime().toRelative();
      groups.putIfAbsent(date, () => []).add(t);
    }
    return groups;
  }
}

class _DateHeader extends StatelessWidget {
  final String date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        date,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isIncome = transaction.amountCents > 0;
    final categoriesAsync = ref.watch(allCategoriesProvider);

    // Find category name
    String? categoryName;
    if (transaction.categoryId != null) {
      categoriesAsync.whenData((categories) {
        final cat = categories.where((c) => c.id == transaction.categoryId).firstOrNull;
        if (cat != null) categoryName = cat.name;
      });
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIncome
            ? Colors.green.withValues(alpha: 0.15)
            : colorScheme.errorContainer,
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncome ? Colors.green : colorScheme.error,
          size: 20,
        ),
      ),
      title: Text(
        transaction.payee,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        categoryName ?? (transaction.categoryId == null ? 'Uncategorized' : ''),
        style: theme.textTheme.bodySmall?.copyWith(
          color: transaction.categoryId == null
              ? colorScheme.error.withValues(alpha: 0.7)
              : colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            transaction.amountCents.toCurrency(),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isIncome ? Colors.green : colorScheme.onSurface,
            ),
          ),
          if (transaction.isPending)
            Text(
              'Pending',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      onTap: () {
        // TODO: Navigate to transaction detail/edit
      },
    );
  }
}

class _FilterBottomSheet extends StatelessWidget {
  const _FilterBottomSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          // Date range
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Date Range'),
            subtitle: const Text('All time'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Date range picker
            },
          ),
          // Category
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Category'),
            subtitle: const Text('All categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Category filter
            },
          ),
          // Account
          ListTile(
            leading: const Icon(Icons.account_balance),
            title: const Text('Account'),
            subtitle: const Text('All accounts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Account filter
            },
          ),
          // Amount range
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Amount Range'),
            subtitle: const Text('Any amount'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Amount range filter
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply Filters'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

