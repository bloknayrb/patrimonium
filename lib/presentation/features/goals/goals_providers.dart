import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';
import '../../../domain/usecases/retirement/monte_carlo_service.dart';

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

/// Watch a single goal reactively (for detail screen).
final goalStreamProvider = StreamProvider.autoDispose.family<Goal?, String>((ref, id) {
  return ref.watch(goalRepositoryProvider).watchGoalById(id);
});

/// Monte Carlo simulation results for a retirement goal.
/// Runs off the UI thread via Isolate.run().
final monteCarloProvider =
    FutureProvider.autoDispose.family<MonteCarloResult?, String>((ref, goalId) async {
  final goal = await ref.watch(goalStreamProvider(goalId).future);
  if (goal == null) return null;

  final contribution = goal.monthlyContributionCents;
  final returnBps = goal.annualReturnBps;
  final volBps = goal.annualVolatilityBps;
  final year = goal.retirementYear;
  if (contribution == null || returnBps == null || volBps == null || year == null) {
    return null;
  }

  final input = MonteCarloInput(
    currentBalanceCents: goal.currentAmountCents,
    monthlyContributionCents: contribution,
    annualReturn: returnBps / 10000.0,
    annualVolatility: volBps / 10000.0,
    yearsToRetirement: year - DateTime.now().year,
  );

  return Isolate.run(() => runMonteCarloSimulation(input));
});
