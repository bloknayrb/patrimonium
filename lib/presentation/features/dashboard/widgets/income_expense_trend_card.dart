import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/money_extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../analytics/analytics_providers.dart';

/// 6-month grouped bar chart comparing income (green) vs expenses (red).
class IncomeExpenseTrendCard extends ConsumerWidget {
  const IncomeExpenseTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final finance = theme.finance;
    final cashFlowAsync = ref.watch(monthlyCashFlowProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.analytics),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Income vs Expenses',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Legend
              Row(
                children: [
                  _LegendDot(color: finance.income, label: 'Income'),
                  const SizedBox(width: 16),
                  _LegendDot(color: finance.expense, label: 'Expenses'),
                ],
              ),
              const SizedBox(height: 12),
              cashFlowAsync.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const SizedBox(
                  height: 180,
                  child: Center(child: Text('Unable to load data')),
                ),
                data: (cashFlow) {
                  if (cashFlow.isEmpty) {
                    return SizedBox(
                      height: 180,
                      child: Center(
                        child: Text(
                          'No data yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 180,
                    child: _IncomeExpenseChart(
                      data: cashFlow,
                      incomeColor: finance.income,
                      expenseColor: finance.expense,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _IncomeExpenseChart extends StatelessWidget {
  final List<dynamic> data;
  final Color incomeColor;
  final Color expenseColor;

  const _IncomeExpenseChart({
    required this.data,
    required this.incomeColor,
    required this.expenseColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthFmt = DateFormat.MMM();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY.round();
              final label = rodIndex == 0 ? 'Income' : 'Expenses';
              return BarTooltipItem(
                '$label\n${value.toCurrency()}',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) {
                  return const SizedBox.shrink();
                }
                final item = data[idx];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    monthFmt.format(item.month as DateTime),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: [
          for (var i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (data[i].incomeCents as int) / 100.0,
                  color: incomeColor,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
                BarChartRodData(
                  toY: (data[i].expenseCents as int).abs() / 100.0,
                  color: expenseColor,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
