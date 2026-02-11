import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

/// Repository for goal CRUD and progress tracking operations.
class GoalRepository {
  GoalRepository(this._db);

  final AppDatabase _db;

  /// Watch active (incomplete) goals ordered by target date.
  Stream<List<Goal>> watchActiveGoals() {
    return (_db.select(_db.goals)
          ..where((g) => g.isCompleted.equals(false))
          ..orderBy([
            (g) => OrderingTerm.asc(g.targetDate),
            (g) => OrderingTerm.asc(g.createdAt),
          ]))
        .watch();
  }

  /// Watch all goals including completed ones.
  Stream<List<Goal>> watchAllGoals() {
    return (_db.select(_db.goals)
          ..orderBy([
            (g) => OrderingTerm.asc(g.isCompleted),
            (g) => OrderingTerm.asc(g.targetDate),
            (g) => OrderingTerm.asc(g.createdAt),
          ]))
        .watch();
  }

  /// Get a single goal by ID.
  Future<Goal?> getGoalById(String id) {
    return (_db.select(_db.goals)..where((g) => g.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new goal.
  Future<void> insertGoal(GoalsCompanion goal) {
    return _db.into(_db.goals).insert(goal);
  }

  /// Update an existing goal.
  Future<bool> updateGoal(GoalsCompanion goal) {
    return (_db.update(_db.goals)..where((g) => g.id.equals(goal.id.value)))
        .write(goal)
        .then((rows) => rows > 0);
  }

  /// Update the current progress amount for a goal.
  Future<void> updateProgress(String id, int currentAmountCents) {
    return (_db.update(_db.goals)..where((g) => g.id.equals(id)))
        .write(GoalsCompanion(
      currentAmountCents: Value(currentAmountCents),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Mark a goal as completed.
  Future<void> markCompleted(String id) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_db.update(_db.goals)..where((g) => g.id.equals(id)))
        .write(GoalsCompanion(
      isCompleted: const Value(true),
      completedAt: Value(now),
      updatedAt: Value(now),
    ));
  }

  /// Delete a goal by ID.
  Future<int> deleteGoal(String id) {
    return (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
  }

  /// Check if any goals exist.
  Future<bool> hasGoals() async {
    final count = _db.goals.id.count();
    final result = await (_db.selectOnly(_db.goals)
          ..addColumns([count]))
        .getSingle();
    return (result.read(count) ?? 0) > 0;
  }
}
