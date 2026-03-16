import '../../../core/extensions/money_extensions.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/transaction_repository.dart';

/// Budget paired with its computed spending data for the current period.
class BudgetWithSpent {
  final Budget budget;
  final int spentCents;
  final double percentage;

  const BudgetWithSpent({
    required this.budget,
    required this.spentCents,
    required this.percentage,
  });
}

/// Enriches budgets with spending data by collecting subcategories
/// and issuing batch queries.
class BudgetSpendingService {
  BudgetSpendingService({
    required TransactionRepository transactionRepo,
    required CategoryRepository categoryRepo,
  })  : _transactionRepo = transactionRepo,
        _categoryRepo = categoryRepo;

  final TransactionRepository _transactionRepo;
  final CategoryRepository _categoryRepo;

  Future<List<BudgetWithSpent>> getBudgetsWithSpending(
    List<Budget> budgets,
  ) async {
    if (budgets.isEmpty) return [];

    final now = DateTime.now();
    final monthStart = now.startOfMonth.millisecondsSinceEpoch;
    final monthEnd = now.endOfMonth.millisecondsSinceEpoch;
    final yearStart = DateTime(now.year, 1, 1).millisecondsSinceEpoch;
    final yearEnd =
        DateTime(now.year, 12, 31, 23, 59, 59, 999).millisecondsSinceEpoch;

    // Collect all category IDs per budget (parent + subcategories).
    final budgetCategoryIds = <Budget, List<String>>{};
    final allMonthlyIds = <String>{};
    final allAnnualIds = <String>{};

    for (final budget in budgets) {
      final subcategories =
          await _categoryRepo.getSubcategories(budget.categoryId);
      final ids = [budget.categoryId, ...subcategories.map((c) => c.id)];
      budgetCategoryIds[budget] = ids;
      if (budget.periodType == 'monthly') {
        allMonthlyIds.addAll(ids);
      } else {
        allAnnualIds.addAll(ids);
      }
    }

    // Issue at most 2 queries instead of N*M.
    final monthlySpending = allMonthlyIds.isNotEmpty
        ? await _transactionRepo.getTotalExpensesByCategoryIds(
            monthStart, monthEnd, allMonthlyIds.toList())
        : <String, int>{};
    final annualSpending = allAnnualIds.isNotEmpty
        ? await _transactionRepo.getTotalExpensesByCategoryIds(
            yearStart, yearEnd, allAnnualIds.toList())
        : <String, int>{};

    // Map back per budget.
    final results = <BudgetWithSpent>[];
    for (final budget in budgets) {
      final isMonthly = budget.periodType == 'monthly';
      final spending = isMonthly ? monthlySpending : annualSpending;
      final ids = budgetCategoryIds[budget]!;
      var spentCents = 0;
      for (final id in ids) {
        spentCents += (spending[id] ?? 0).abs();
      }

      final percentage = budget.amountCents > 0
          ? spentCents.toDouble() / budget.amountCents
          : 0.0;

      results.add(BudgetWithSpent(
        budget: budget,
        spentCents: spentCents,
        percentage: percentage,
      ));
    }

    return results;
  }
}
