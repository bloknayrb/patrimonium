import '../../../data/repositories/transaction_repository.dart';

/// A detected recurring transaction pattern.
class DetectedRecurring {
  final String payee;
  final int amountCents;
  final String frequency;
  final String accountId;
  final String? categoryId;
  final int nextExpectedDate;
  final int lastOccurrenceDate;
  final int occurrenceCount;
  final double confidence;

  const DetectedRecurring({
    required this.payee,
    required this.amountCents,
    required this.frequency,
    required this.accountId,
    this.categoryId,
    required this.nextExpectedDate,
    required this.lastOccurrenceDate,
    required this.occurrenceCount,
    required this.confidence,
  });
}

/// Service that detects recurring patterns from transaction history.
class RecurringDetectionService {
  RecurringDetectionService(this._transactionRepo);

  final TransactionRepository _transactionRepo;

  /// Known frequency patterns: name, expected interval in days, tolerance ratio.
  static const _frequencies = [
    ('weekly', 7),
    ('biweekly', 14),
    ('monthly', 30),
    ('quarterly', 90),
    ('annual', 365),
  ];

  /// Analyze transaction history and return detected recurring patterns.
  Future<List<DetectedRecurring>> detectRecurringPatterns() async {
    final transactions = await _transactionRepo.getAllTransactions();
    if (transactions.isEmpty) return [];

    // Group by normalized payee + account.
    final groups = <String, List<_TxInfo>>{};
    for (final t in transactions) {
      final key = '${t.payee.toLowerCase().trim()}|${t.accountId}';
      groups.putIfAbsent(key, () => []).add(_TxInfo(
        date: t.date,
        amountCents: t.amountCents,
        categoryId: t.categoryId,
        payee: t.payee,
        accountId: t.accountId,
      ));
    }

    final results = <DetectedRecurring>[];

    for (final entry in groups.entries) {
      final txs = entry.value;
      if (txs.length < 3) continue;

      // Sort by date ascending.
      txs.sort((a, b) => a.date.compareTo(b.date));

      // Calculate intervals in days between consecutive transactions.
      final intervals = <double>[];
      for (var i = 1; i < txs.length; i++) {
        final diffMs = txs[i].date - txs[i - 1].date;
        final diffDays = diffMs / (1000 * 60 * 60 * 24);
        if (diffDays > 0) intervals.add(diffDays);
      }

      if (intervals.isEmpty) continue;

      final avgInterval =
          intervals.reduce((a, b) => a + b) / intervals.length;

      // Find the best matching frequency.
      String? bestFrequency;
      double bestConfidence = 0;

      for (final (name, expectedDays) in _frequencies) {
        // Check if average interval is within 20% of expected.
        final tolerance = expectedDays * 0.2;
        if ((avgInterval - expectedDays).abs() > tolerance) continue;

        // Calculate confidence: how consistent are the intervals?
        var consistentCount = 0;
        for (final interval in intervals) {
          if ((interval - expectedDays).abs() <= tolerance) {
            consistentCount++;
          }
        }
        final confidence = consistentCount / intervals.length;

        if (confidence > bestConfidence) {
          bestConfidence = confidence;
          bestFrequency = name;
        }
      }

      if (bestFrequency == null || bestConfidence <= 0.6) continue;

      // Use the most common amount (mode).
      final amountCounts = <int, int>{};
      for (final tx in txs) {
        amountCounts[tx.amountCents] =
            (amountCounts[tx.amountCents] ?? 0) + 1;
      }
      final modeAmount = amountCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      // Use the most recent category.
      final lastCategoryId = txs.last.categoryId;

      // Calculate next expected date.
      final lastDate = txs.last.date;
      final intervalMs = _intervalMs(bestFrequency);
      final nextExpected = lastDate + intervalMs;

      results.add(DetectedRecurring(
        payee: txs.last.payee, // Use original casing from most recent.
        amountCents: modeAmount,
        frequency: bestFrequency,
        accountId: txs.last.accountId,
        categoryId: lastCategoryId,
        nextExpectedDate: nextExpected,
        lastOccurrenceDate: lastDate,
        occurrenceCount: txs.length,
        confidence: bestConfidence,
      ));
    }

    // Sort by confidence descending.
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  /// Convert a frequency name to milliseconds.
  static int _intervalMs(String frequency) {
    const msPerDay = 1000 * 60 * 60 * 24;
    return switch (frequency) {
      'weekly' => 7 * msPerDay,
      'biweekly' => 14 * msPerDay,
      'monthly' => 30 * msPerDay,
      'quarterly' => 90 * msPerDay,
      'annual' => 365 * msPerDay,
      _ => 30 * msPerDay,
    };
  }
}

/// Lightweight holder for grouping transaction data.
class _TxInfo {
  final int date;
  final int amountCents;
  final String? categoryId;
  final String payee;
  final String accountId;

  _TxInfo({
    required this.date,
    required this.amountCents,
    this.categoryId,
    required this.payee,
    required this.accountId,
  });
}
