import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';
import '../../../domain/usecases/recurring/recurring_detection_service.dart';

/// Watch active recurring transactions.
final recurringTransactionsProvider =
    StreamProvider.autoDispose<List<RecurringTransaction>>((ref) {
  return ref.watch(recurringTransactionRepositoryProvider).watchActiveRecurring();
});

/// Watch all recurring transactions (including inactive).
final allRecurringProvider =
    StreamProvider.autoDispose<List<RecurringTransaction>>((ref) {
  return ref.watch(recurringTransactionRepositoryProvider).watchAllRecurring();
});

/// Run detection analysis on transaction history.
final detectedRecurringProvider =
    FutureProvider.autoDispose<List<DetectedRecurring>>((ref) {
  return ref.watch(recurringDetectionServiceProvider).detectRecurringPatterns();
});

/// Get a single recurring transaction by ID.
final recurringByIdProvider =
    FutureProvider.autoDispose.family<RecurringTransaction?, String>((ref, id) {
  return ref.watch(recurringTransactionRepositoryProvider).getRecurringById(id);
});
