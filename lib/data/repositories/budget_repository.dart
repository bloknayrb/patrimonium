import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

/// Repository for budget CRUD and tracking operations.
class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  /// Watch all active budgets (no end date or end date in the future).
  Stream<List<Budget>> watchActiveBudgets() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_db.select(_db.budgets)
          ..where((b) =>
              b.endDate.isNull() | b.endDate.isBiggerOrEqualValue(now))
          ..orderBy([(b) => OrderingTerm.asc(b.categoryId)]))
        .watch();
  }

  /// Get all budgets.
  Future<List<Budget>> getAllBudgets() {
    return (_db.select(_db.budgets)).get();
  }

  /// Get budget for a specific category.
  Future<Budget?> getBudgetForCategory(String categoryId) {
    return (_db.select(_db.budgets)
          ..where((b) => b.categoryId.equals(categoryId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get a budget by ID.
  Future<Budget?> getBudgetById(String id) {
    return (_db.select(_db.budgets)..where((b) => b.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new budget.
  Future<void> insertBudget(BudgetsCompanion budget) {
    return _db.into(_db.budgets).insert(budget);
  }

  /// Update an existing budget.
  Future<bool> updateBudget(BudgetsCompanion budget) {
    return (_db.update(_db.budgets)
          ..where((b) => b.id.equals(budget.id.value)))
        .write(budget)
        .then((rows) => rows > 0);
  }

  /// Update rollover amount.
  Future<void> updateRolloverAmount(String id, int rolloverAmountCents) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(id)))
        .write(BudgetsCompanion(
      rolloverAmountCents: Value(rolloverAmountCents),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Delete a budget by ID.
  Future<int> deleteBudget(String id) {
    return (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
  }

  /// Check if any budgets exist.
  Future<bool> hasBudgets() async {
    final count = _db.budgets.id.count();
    final result = await (_db.selectOnly(_db.budgets)
          ..addColumns([count]))
        .getSingle();
    return (result.read(count) ?? 0) > 0;
  }
}
