import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

/// Repository for recurring transaction CRUD operations.
class RecurringTransactionRepository {
  RecurringTransactionRepository(this._db);

  final AppDatabase _db;

  /// Watch active recurring transactions.
  Stream<List<RecurringTransaction>> watchActiveRecurring() {
    return (_db.select(_db.recurringTransactions)
          ..where((r) => r.isActive.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.nextExpectedDate)]))
        .watch();
  }

  /// Watch all recurring transactions.
  Stream<List<RecurringTransaction>> watchAllRecurring() {
    return (_db.select(_db.recurringTransactions)
          ..orderBy([(r) => OrderingTerm.asc(r.nextExpectedDate)]))
        .watch();
  }

  /// Get a single recurring transaction by ID.
  Future<RecurringTransaction?> getRecurringById(String id) {
    return (_db.select(_db.recurringTransactions)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new recurring transaction.
  Future<void> insertRecurring(RecurringTransactionsCompanion recurring) {
    return _db.into(_db.recurringTransactions).insert(recurring);
  }

  /// Update an existing recurring transaction.
  Future<bool> updateRecurring(RecurringTransactionsCompanion recurring) {
    return (_db.update(_db.recurringTransactions)
          ..where((r) => r.id.equals(recurring.id.value)))
        .write(recurring)
        .then((rows) => rows > 0);
  }

  /// Delete a recurring transaction by ID.
  Future<int> deleteRecurring(String id) {
    return (_db.delete(_db.recurringTransactions)
          ..where((r) => r.id.equals(id)))
        .go();
  }

  /// Deactivate a recurring transaction (set isActive=false).
  Future<void> deactivateRecurring(String id) {
    return (_db.update(_db.recurringTransactions)
          ..where((r) => r.id.equals(id)))
        .write(RecurringTransactionsCompanion(
      isActive: const Value(false),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Update the next expected date for a recurring transaction.
  Future<void> updateNextExpectedDate(String id, int nextDate) {
    return (_db.update(_db.recurringTransactions)
          ..where((r) => r.id.equals(id)))
        .write(RecurringTransactionsCompanion(
      nextExpectedDate: Value(nextDate),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }
}
