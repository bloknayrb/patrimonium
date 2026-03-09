import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Builds a financial context snapshot for injection into LLM prompts.
///
/// Prioritized layers — lower priority layers are dropped if token budget exceeded.
/// Rough token estimate: content.length ~/ 4.
class ContextBuilder {
  ContextBuilder({
    required AccountRepository accountRepo,
    required TransactionRepository transactionRepo,
    required CategoryRepository categoryRepo,
    required BudgetRepository budgetRepo,
    required GoalRepository goalRepo,
  })  : _accountRepo = accountRepo,
        _transactionRepo = transactionRepo,
        _categoryRepo = categoryRepo,
        _budgetRepo = budgetRepo,
        _goalRepo = goalRepo;

  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;
  final CategoryRepository _categoryRepo;
  final BudgetRepository _budgetRepo;
  final GoalRepository _goalRepo;

  static const _tokenBudget = 2000;

  /// Returns a formatted financial context string for injection as a user message.
  Future<String> buildContext() async {
    final sections = <String>[];

    // Priority 1: Account summary + net worth (always included)
    final accountSection = await _buildAccountSection();
    sections.add(accountSection);

    // Priority 2: Recent transactions (always included — needed for specific queries)
    final txSection = await _buildTransactionSection();
    sections.add(txSection);

    // Priority 3: Category spending totals
    final spendingSection = await _buildSpendingSection();
    sections.add(spendingSection);

    // Check token budget before adding lower priority sections
    final currentTokens = sections.join('\n\n').length ~/ 4;

    if (currentTokens < _tokenBudget) {
      // Priority 4: Active budgets
      final budgetSection = await _buildBudgetSection();
      if (budgetSection.isNotEmpty) {
        final withBudget = [...sections, budgetSection].join('\n\n');
        if (withBudget.length ~/ 4 < _tokenBudget) {
          sections.add(budgetSection);
        }
      }
    }

    if (sections.join('\n\n').length ~/ 4 < _tokenBudget) {
      // Priority 5: Active goals
      final goalSection = await _buildGoalSection();
      if (goalSection.isNotEmpty) {
        sections.add(goalSection);
      }
    }

    return '## Your Financial Data\n\n${sections.join('\n\n')}';
  }

  Future<String> _buildAccountSection() async {
    final accounts = await _accountRepo.getAllAccounts();
    final netWorth = await _accountRepo.getNetWorth();

    if (accounts.isEmpty) {
      return '### Accounts\nNo accounts added yet.';
    }

    // Show top 10 by absolute balance
    final top = (accounts.toList()
          ..sort((a, b) => b.balanceCents.abs().compareTo(a.balanceCents.abs())))
        .take(10);

    final lines = top.map((a) {
      final balance = '\$${(a.balanceCents / 100).toStringAsFixed(2)}';
      return '- ${a.name} (${a.accountType}): $balance';
    });

    final nw = '\$${(netWorth / 100).toStringAsFixed(2)}';
    return '### Accounts (Net Worth: $nw)\n${lines.join('\n')}';
  }

  Future<String> _buildTransactionSection() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final transactions = await _transactionRepo.getTransactionsByDateRange(
      thirtyDaysAgo.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );

    if (transactions.isEmpty) {
      return '### Recent Transactions\nNo transactions in the last 30 days.';
    }

    // Most recent 20 transactions
    final recent = transactions
        .sorted((a, b) => b.date.compareTo(a.date))
        .take(20);

    final lines = recent.map((t) {
      final amount = '\$${(t.amountCents / 100).toStringAsFixed(2)}';
      final date = DateTime.fromMillisecondsSinceEpoch(t.date);
      final dateStr = '${date.month}/${date.day}';
      return '- $dateStr ${t.payee}: $amount';
    });

    return '### Recent Transactions (last 30 days)\n${lines.join('\n')}';
  }

  Future<String> _buildSpendingSection() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final transactions = await _transactionRepo.getTransactionsByDateRange(
      thirtyDaysAgo.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );

    final expenseTransactions =
        transactions.where((t) => t.amountCents < 0 && t.categoryId != null);

    if (expenseTransactions.isEmpty) {
      return '';
    }

    // Aggregate by category ID
    final categoryTotals = <String, int>{};
    for (final t in expenseTransactions) {
      categoryTotals[t.categoryId!] =
          (categoryTotals[t.categoryId!] ?? 0) + t.amountCents.abs();
    }

    // Fetch category names
    final categories = await _categoryRepo.getAllCategories();
    final categoryMap = {for (final c in categories) c.id: c.name};

    // Top 10 by spending amount
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final lines = sorted.take(10).map((e) {
      final name = categoryMap[e.key] ?? 'Unknown';
      final amount = '\$${(e.value / 100).toStringAsFixed(2)}';
      return '- $name: $amount';
    });

    return '### Spending by Category (last 30 days)\n${lines.join('\n')}';
  }

  Future<String> _buildBudgetSection() async {
    final budgets = await _budgetRepo.getAllBudgets();
    if (budgets.isEmpty) return '';

    final categories = await _categoryRepo.getAllCategories();
    final categoryMap = {for (final c in categories) c.id: c.name};

    final lines = budgets.take(10).map((b) {
      final name = categoryMap[b.categoryId] ?? 'Unknown';
      final budget = '\$${(b.amountCents / 100).toStringAsFixed(2)}';
      return '- $name: $budget/${b.periodType}';
    });

    return '### Active Budgets\n${lines.join('\n')}';
  }

  Future<String> _buildGoalSection() async {
    final goals = await _goalRepo.watchActiveGoals().first;
    if (goals.isEmpty) return '';

    final lines = goals.take(5).map((g) {
      final target = '\$${(g.targetAmountCents / 100).toStringAsFixed(2)}';
      final current = '\$${(g.currentAmountCents / 100).toStringAsFixed(2)}';
      final pct =
          g.targetAmountCents > 0 ? (g.currentAmountCents * 100 ~/ g.targetAmountCents) : 0;
      return '- ${g.name}: $current / $target ($pct%)';
    });

    return '### Active Goals\n${lines.join('\n')}';
  }
}

extension _ListExt<T> on Iterable<T> {
  List<T> sorted(int Function(T, T) compare) {
    final list = toList();
    list.sort(compare);
    return list;
  }
}
