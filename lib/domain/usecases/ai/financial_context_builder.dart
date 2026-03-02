import '../../../core/extensions/money_extensions.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Builds a financial context snapshot for LLM system prompts.
///
/// Gathers the user's accounts, transactions, budgets, and goals
/// and formats them as a plain-text summary for injection into
/// LLM conversations and insight generation requests.
class FinancialContextBuilder {
  FinancialContextBuilder({
    required AccountRepository accountRepo,
    required TransactionRepository transactionRepo,
    required BudgetRepository budgetRepo,
    required GoalRepository goalRepo,
  })  : _accountRepo = accountRepo,
        _transactionRepo = transactionRepo,
        _budgetRepo = budgetRepo,
        _goalRepo = goalRepo;

  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;
  final BudgetRepository _budgetRepo;
  final GoalRepository _goalRepo;

  /// Build a formatted financial snapshot.
  Future<String> build() async {
    final now = DateTime.now();
    final buf = StringBuffer();
    buf.writeln('== Financial Snapshot (${now.toMediumDate()}) ==');
    buf.writeln();

    await _appendAccounts(buf);
    await _appendMonthlyTotals(buf, now);
    await _appendRecentTransactions(buf);
    await _appendBudgets(buf);
    await _appendGoals(buf);

    return buf.toString();
  }

  Future<void> _appendAccounts(StringBuffer buf) async {
    final accounts = await _accountRepo.getAllAccounts();
    if (accounts.isEmpty) {
      buf.writeln('No accounts set up yet.');
      buf.writeln();
      return;
    }

    buf.writeln('Accounts:');
    for (final a in accounts) {
      buf.writeln('- ${a.name} (${a.accountType}): ${a.balanceCents.toCurrency()}');
    }

    final netWorth = await _accountRepo.getNetWorth();
    buf.writeln('Net Worth: ${netWorth.toCurrency()}');
    buf.writeln();
  }

  Future<void> _appendMonthlyTotals(StringBuffer buf, DateTime now) async {
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999)
        .millisecondsSinceEpoch;

    final income = await _transactionRepo.getTotalIncome(start, end);
    final expenses = await _transactionRepo.getTotalExpenses(start, end);

    buf.writeln('This Month (${now.toMonthYear()}):');
    buf.writeln('- Income: ${income.toCurrency()}  |  Expenses: ${expenses.abs().toCurrency()}');
    buf.writeln();
  }

  Future<void> _appendRecentTransactions(StringBuffer buf) async {
    final transactions = await _transactionRepo.getRecentTransactions(limit: 20);
    if (transactions.isEmpty) return;

    buf.writeln('Recent Transactions (last ${transactions.length}):');
    for (final t in transactions) {
      final date = t.date.toDateTime().toMediumDate();
      final amount = t.amountCents.toCurrency();
      buf.writeln('- $date: ${t.payee} $amount');
    }
    buf.writeln();
  }

  Future<void> _appendBudgets(StringBuffer buf) async {
    final budgets = await _budgetRepo.getAllBudgets();
    if (budgets.isEmpty) return;

    buf.writeln('Budgets:');
    for (final b in budgets) {
      final limit = b.amountCents.toCurrency();
      buf.writeln('- Category ${b.categoryId}: $limit ${b.periodType} budget');
    }
    buf.writeln();
  }

  Future<void> _appendGoals(StringBuffer buf) async {
    final goals = await _goalRepo.watchActiveGoals().first;
    if (goals.isEmpty) return;

    buf.writeln('Goals:');
    for (final g in goals) {
      final current = g.currentAmountCents.toCurrency();
      final target = g.targetAmountCents.toCurrency();
      final pct = g.targetAmountCents > 0
          ? ((g.currentAmountCents / g.targetAmountCents) * 100).round()
          : 0;
      final deadline = g.targetDate != null
          ? ' — due ${g.targetDate!.toDateTime().toMediumDate()}'
          : '';
      buf.writeln('- ${g.name}: $current / $target ($pct%)$deadline');
    }
    buf.writeln();
  }
}
