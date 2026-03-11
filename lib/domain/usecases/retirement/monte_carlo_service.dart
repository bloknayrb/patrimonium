import 'dart:math';

/// Input parameters for Monte Carlo retirement simulation.
class MonteCarloInput {
  final int currentBalanceCents;
  final int monthlyContributionCents;
  final double annualReturn;    // e.g. 0.045 (real, inflation-adjusted)
  final double annualVolatility; // e.g. 0.15
  final int yearsToRetirement;
  final int numSimulations;     // typically 1000

  const MonteCarloInput({
    required this.currentBalanceCents,
    required this.monthlyContributionCents,
    required this.annualReturn,
    required this.annualVolatility,
    required this.yearsToRetirement,
    this.numSimulations = 1000,
  });
}

/// Percentile bands at each year for rendering a fan chart.
class MonteCarloResult {
  final List<int> years;  // [0, 1, 2, ..., N]
  final List<int> p10;    // cents at each year
  final List<int> p25;
  final List<int> p50;
  final List<int> p75;
  final List<int> p90;

  const MonteCarloResult({
    required this.years,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
  });
}

/// Top-level function so it can be used with Isolate.run().
///
/// Simulates [input.numSimulations] retirement paths using log-normal returns,
/// then extracts percentile bands at each year boundary.
MonteCarloResult runMonteCarloSimulation(MonteCarloInput input) {
  final n = input.yearsToRetirement;
  if (n <= 0) {
    return MonteCarloResult(
      years: const [0],
      p10: [input.currentBalanceCents],
      p25: [input.currentBalanceCents],
      p50: [input.currentBalanceCents],
      p75: [input.currentBalanceCents],
      p90: [input.currentBalanceCents],
    );
  }

  final rng = Random(42); // deterministic for reproducibility
  final mu = input.annualReturn;
  final sigma = input.annualVolatility;

  // Monthly log-normal parameters
  final monthlyDrift = (mu - sigma * sigma / 2) / 12;
  final monthlySigma = sigma / sqrt(12);

  // balances[year][simulation] — store year-end balances across all sims
  final balances = List.generate(
    n + 1,
    (_) => List<double>.filled(input.numSimulations, 0),
  );

  for (var sim = 0; sim < input.numSimulations; sim++) {
    double balance = input.currentBalanceCents.toDouble();
    balances[0][sim] = balance;

    for (var year = 0; year < n; year++) {
      for (var month = 0; month < 12; month++) {
        // Box-Muller transform for normal random
        final z = _normalRandom(rng);
        final monthlyReturn = exp(monthlyDrift + monthlySigma * z);
        balance = balance * monthlyReturn + input.monthlyContributionCents;
        if (balance < 0) balance = 0;
      }
      balances[year + 1][sim] = balance;
    }
  }

  // Extract percentiles at each year
  final years = List.generate(n + 1, (i) => i);
  final p10 = <int>[];
  final p25 = <int>[];
  final p50 = <int>[];
  final p75 = <int>[];
  final p90 = <int>[];

  for (var year = 0; year <= n; year++) {
    final sorted = balances[year]..sort();
    p10.add(_percentile(sorted, 0.10).round());
    p25.add(_percentile(sorted, 0.25).round());
    p50.add(_percentile(sorted, 0.50).round());
    p75.add(_percentile(sorted, 0.75).round());
    p90.add(_percentile(sorted, 0.90).round());
  }

  return MonteCarloResult(
    years: years,
    p10: p10,
    p25: p25,
    p50: p50,
    p75: p75,
    p90: p90,
  );
}

/// Box-Muller transform: generates a standard normal random variable.
double _normalRandom(Random rng) {
  final u1 = rng.nextDouble();
  final u2 = rng.nextDouble();
  return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
}

/// Linear interpolation percentile from a sorted list.
double _percentile(List<double> sorted, double p) {
  final index = p * (sorted.length - 1);
  final lower = index.floor();
  final upper = index.ceil();
  if (lower == upper) return sorted[lower];
  final frac = index - lower;
  return sorted[lower] * (1 - frac) + sorted[upper] * frac;
}
