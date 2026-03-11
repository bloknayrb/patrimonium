import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/database/app_database.dart';
import '../../shared/loading/shimmer_loading.dart';
import 'edit_retirement_params_screen.dart';
import 'goals_providers.dart';
import 'widgets/retirement_projection_chart.dart';

/// Detail screen for a retirement goal with Monte Carlo fan chart.
class RetirementGoalDetailScreen extends ConsumerWidget {
  const RetirementGoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(goalStreamProvider(goalId));
    final mcAsync = ref.watch(monteCarloProvider(goalId));
    final theme = Theme.of(context);
    final finance = theme.finance;

    return Scaffold(
      appBar: AppBar(
        title: goalAsync.when(
          data: (g) => Text(g?.name ?? 'Retirement Plan'),
          loading: () => const Text('Retirement Plan'),
          error: (_, _) => const Text('Retirement Plan'),
        ),
      ),
      body: goalAsync.when(
        loading: () => const ShimmerTransactionList(itemCount: 4),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goal) {
          if (goal == null) {
            return const Center(child: Text('Goal not found'));
          }

          // Check if retirement params are configured
          if (goal.retirementYear == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.beach_access, size: 64,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'Complete your retirement plan setup',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _navigateToEdit(context, goal),
                      icon: const Icon(Icons.edit),
                      label: const Text('Set Up Parameters'),
                    ),
                  ],
                ),
              ),
            );
          }

          final yearsLeft = goal.retirementYear! - DateTime.now().year;
          if (yearsLeft <= 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration, size: 64,
                        color: finance.income),
                    const SizedBox(height: 16),
                    Text(
                      'Your target retirement year has passed!',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Edit your plan to set a new target year.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              // Summary cards
              _SummaryCards(goal: goal, yearsLeft: yearsLeft),
              // Fan chart
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                child: mcAsync.when(
                  loading: () => const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SizedBox(
                    height: 240,
                    child: Center(child: Text('Simulation error: $e')),
                  ),
                  data: (result) {
                    if (result == null) {
                      return const SizedBox(
                        height: 240,
                        child: Center(child: Text('Missing parameters')),
                      );
                    }
                    return RetirementProjectionChart(
                      result: result,
                      targetAmountCents: goal.targetAmountCents,
                      startYear: DateTime.now().year,
                    );
                  },
                ),
              ),
              // Legend
              const _ChartLegend(),
              // Inflation note
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  "Values shown in today's dollars (inflation-adjusted)",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: goalAsync.whenOrNull(
        data: (goal) => goal != null
            ? FloatingActionButton(
                onPressed: () => _navigateToEdit(context, goal),
                child: const Icon(Icons.edit),
              )
            : null,
      ),
    );
  }

  void _navigateToEdit(BuildContext context, Goal goal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditRetirementParamsScreen(goal: goal),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.goal, required this.yearsLeft});

  final Goal goal;
  final int yearsLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InfoChip(
            label: 'Current Balance',
            value: goal.currentAmountCents.toCurrency(),
          ),
          if (goal.monthlyContributionCents != null)
            _InfoChip(
              label: 'Monthly Contribution',
              value: goal.monthlyContributionCents!.toCurrency(),
            ),
          _InfoChip(
            label: 'Target Year',
            value: '${goal.retirementYear} ($yearsLeft yrs)',
          ),
          if (goal.annualReturnBps != null)
            _InfoChip(
              label: 'Expected Real Return',
              value: '${(goal.annualReturnBps! / 100).toStringAsFixed(1)}%',
            ),
          if (goal.desiredMonthlyIncomeCents != null)
            _InfoChip(
              label: 'Desired Monthly Income',
              value: goal.desiredMonthlyIncomeCents!.toCurrency(),
            ),
          _InfoChip(
            label: 'Target (25x Rule)',
            value: goal.targetAmountCents.toCurrency(),
            highlight: true,
            highlightColor: colorScheme.primaryContainer,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    this.highlight = false,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: highlight ? highlightColor : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final finance = Theme.of(context).finance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(
            color: finance.income.withValues(alpha: 0.08),
            label: '10th–90th',
          ),
          const SizedBox(width: 16),
          _LegendItem(
            color: finance.income.withValues(alpha: 0.18),
            label: '25th–75th',
          ),
          const SizedBox(width: 16),
          _LegendItem(
            color: finance.income,
            label: 'Median',
            isLine: true,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  final Color color;
  final String label;
  final bool isLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(width: 16, height: 3, color: color)
        else
          Container(
            width: 16,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
