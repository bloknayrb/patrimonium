import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';

/// Watch active (incomplete) goals ordered by target date.
final goalsProvider = StreamProvider.autoDispose<List<Goal>>((ref) {
  return ref.watch(goalRepositoryProvider).watchActiveGoals();
});

/// Watch all goals including completed ones.
final allGoalsProvider = StreamProvider.autoDispose<List<Goal>>((ref) {
  return ref.watch(goalRepositoryProvider).watchAllGoals();
});

/// Get a single goal by ID.
final goalByIdProvider = FutureProvider.autoDispose.family<Goal?, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).getGoalById(id);
});
