import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../shared/empty_states/empty_state_widget.dart';
import '../../shared/loading/shimmer_loading.dart';
import '../../shared/widgets/category_picker_sheet.dart';
import '../accounts/accounts_providers.dart';
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
          Builder(builder: (context) {
            final hasFilters = ref.watch(transactionFiltersProvider).hasAny;
            return IconButton(
              icon: Badge(
                isLabelVisible: hasFilters,
                child: const Icon(Icons.filter_list),
              ),
              tooltip: 'Filter',
              onPressed: () => _showFilterSheet(context),
            );
          }),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const ShimmerTransactionList(),
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
class _TransactionListView extends ConsumerWidget {
  final List<Transaction> transactions;

  const _TransactionListView({required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build category lookup map once at the list level
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final categoryNames = <String, String>{};
    categoriesAsync.whenData((categories) {
      for (final c in categories) {
        categoryNames[c.id] = c.name;
      }
    });

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
              _TransactionTile(
                transaction: transaction,
                categoryName: transaction.categoryId != null
                    ? categoryNames[transaction.categoryId!]
                    : null,
              ),
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

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final String? categoryName;

  const _TransactionTile({
    required this.transaction,
    this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final finance = theme.finance;
    final isIncome = transaction.amountCents > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIncome
            ? finance.income.withValues(alpha: 0.15)
            : colorScheme.errorContainer,
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncome ? finance.income : colorScheme.error,
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
              color: isIncome ? finance.income : colorScheme.onSurface,
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddEditTransactionScreen(transaction: transaction),
          ),
        );
      },
    );
  }
}

class _FilterBottomSheet extends ConsumerStatefulWidget {
  const _FilterBottomSheet();

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  late TransactionFilters _filters;
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  // Display names resolved in initState
  String? _categoryName;
  String? _accountName;

  @override
  void initState() {
    super.initState();
    _filters = ref.read(transactionFiltersProvider);
    if (_filters.minAmountCents != null) {
      _minAmountController.text = _filters.minAmountCents!.toCurrencyValue();
    }
    if (_filters.maxAmountCents != null) {
      _maxAmountController.text = _filters.maxAmountCents!.toCurrencyValue();
    }

    // Resolve display names from IDs
    _resolveCategoryName();
    _resolveAccountName();
  }

  void _resolveCategoryName() {
    if (_filters.categoryId == null) return;
    ref.read(allCategoriesProvider).whenData((cats) {
      final cat = cats.where((c) => c.id == _filters.categoryId).firstOrNull;
      if (cat != null) setState(() => _categoryName = cat.name);
    });
  }

  void _resolveAccountName() {
    if (_filters.accountId == null) return;
    ref.read(accountsProvider).whenData((accts) {
      final acct = accts.where((a) => a.id == _filters.accountId).firstOrNull;
      if (acct != null) setState(() => _accountName = acct.name);
    });
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  String _dateRangeLabel() {
    if (_filters.startDate == null && _filters.endDate == null) return 'All time';
    if (_filters.startDate != null && _filters.endDate != null) {
      return '${_filters.startDate!.toMediumDate()} - ${_filters.endDate!.toMediumDate()}';
    }
    if (_filters.startDate != null) return 'From ${_filters.startDate!.toMediumDate()}';
    return 'Until ${_filters.endDate!.toMediumDate()}';
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _filters.startDate != null && _filters.endDate != null
          ? DateTimeRange(start: _filters.startDate!, end: _filters.endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _filters = _filters.copyWith(
          startDate: picked.start,
          endDate: picked.end,
        );
      });
    }
  }

  void _showCategoryPicker() {
    final categoriesAsync = ref.read(allCategoriesProvider);
    categoriesAsync.whenData((categories) async {
      final result = await showCategoryPickerSheet(
        context: context,
        categories: categories,
        selectedCategoryId: _filters.categoryId,
        title: 'Filter by Category',
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _filters = _filters.copyWith(clearCategory: true);
          _categoryName = null;
        });
      } else {
        setState(() {
          _filters = _filters.copyWith(categoryId: result.id);
          _categoryName = result.name;
        });
      }
    });
  }

  void _showAccountPicker() {
    final accountsAsync = ref.read(accountsProvider);
    accountsAsync.whenData((accounts) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter by Account',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filters = _filters.copyWith(clearAccount: true);
                        _accountName = null;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final account in accounts)
                ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: Text(account.name),
                  subtitle: Text(account.balanceCents.toCurrency()),
                  selected: _filters.accountId == account.id,
                  onTap: () {
                    setState(() {
                      _filters =
                          _filters.copyWith(accountId: account.id);
                      _accountName = account.name;
                    });
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      );
    });
  }

  void _applyFilters() {
    // Parse amount fields
    final minText = _minAmountController.text.trim();
    final maxText = _maxAmountController.text.trim();

    var updatedFilters = _filters;
    if (minText.isNotEmpty) {
      final cents = minText.toCents();
      if (cents != null) {
        updatedFilters = updatedFilters.copyWith(minAmountCents: cents);
      }
    } else {
      updatedFilters = updatedFilters.copyWith(clearMinAmount: true);
    }

    if (maxText.isNotEmpty) {
      final cents = maxText.toCents();
      if (cents != null) {
        updatedFilters = updatedFilters.copyWith(maxAmountCents: cents);
      }
    } else {
      updatedFilters = updatedFilters.copyWith(clearMaxAmount: true);
    }

    ref.read(transactionFiltersProvider.notifier).state = updatedFilters;
    Navigator.pop(context);
  }

  void _clearAll() {
    ref.read(transactionFiltersProvider.notifier).state =
        TransactionFilters.empty;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: theme.textTheme.titleLarge),
              if (_filters.hasAny)
                TextButton(
                  onPressed: _clearAll,
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Date range
          ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('Date Range'),
            subtitle: Text(_dateRangeLabel()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_filters.startDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() {
                      _filters = _filters.copyWith(
                        clearStartDate: true,
                        clearEndDate: true,
                      );
                    }),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _pickDateRange,
          ),
          // Category
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Category'),
            subtitle: Text(_categoryName ?? 'All categories'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_filters.categoryId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() {
                      _filters = _filters.copyWith(clearCategory: true);
                      _categoryName = null;
                    }),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _showCategoryPicker,
          ),
          // Account
          ListTile(
            leading: const Icon(Icons.account_balance),
            title: const Text('Account'),
            subtitle: Text(_accountName ?? 'All accounts'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_filters.accountId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() {
                      _filters = _filters.copyWith(clearAccount: true);
                      _accountName = null;
                    }),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _showAccountPicker,
          ),
          // Amount range
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.attach_money),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _minAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      hintText: '0.00',
                      prefixText: '\$ ',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Text('to'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Max',
                      hintText: '0.00',
                      prefixText: '\$ ',
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _applyFilters,
              child: const Text('Apply Filters'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
