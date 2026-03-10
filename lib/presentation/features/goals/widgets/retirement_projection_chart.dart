import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/money_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/usecases/retirement/monte_carlo_service.dart';

/// Fan chart showing Monte Carlo retirement projection percentile bands.
class RetirementProjectionChart extends StatelessWidget {
  const RetirementProjectionChart({
    super.key,
    required this.result,
    this.targetAmountCents,
    this.startYear,
  });

  final MonteCarloResult result;
  final int? targetAmountCents;
  final int? startYear; // actual calendar year for year 0

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = theme.finance;
    final colorScheme = theme.colorScheme;

    if (result.years.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Not enough data for projection')),
      );
    }

    final maxVal = result.p90.reduce((a, b) => a > b ? a : b).toDouble();
    final targetVal = targetAmountCents?.toDouble();
    final chartMax = (targetVal != null && targetVal > maxVal)
        ? targetVal * 1.1
        : maxVal * 1.1;

    // Build FlSpot lists for each percentile
    final spotsP10 = _toSpots(result.p10);
    final spotsP25 = _toSpots(result.p25);
    final spotsP50 = _toSpots(result.p50);
    final spotsP75 = _toSpots(result.p75);
    final spotsP90 = _toSpots(result.p90);

    final primaryColor = finance.income;
    final bandColorOuter = primaryColor.withValues(alpha: 0.08);
    final bandColorInner = primaryColor.withValues(alpha: 0.18);

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: chartMax,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              maxContentWidth: 180,
              getTooltipItems: (spots) {
                // Only show tooltip for p50 line (index 2)
                return spots.map((spot) {
                  if (spot.barIndex != 2) {
                    return null;
                  }
                  final yearIndex = spot.x.toInt();
                  final yearLabel = startYear != null
                      ? '${startYear! + yearIndex}'
                      : 'Year $yearIndex';
                  return LineTooltipItem(
                    '$yearLabel\n${spot.y.round().toCurrency()}',
                    theme.textTheme.bodySmall!.copyWith(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _compactCurrency(value.round()),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _xInterval(result.years.length),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= result.years.length) {
                    return const SizedBox.shrink();
                  }
                  final label = startYear != null
                      ? '${startYear! + index}'
                      : '$index';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label, style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 0.5,
            ),
          ),
          extraLinesData: targetAmountCents != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: targetAmountCents!.toDouble(),
                    color: colorScheme.error.withValues(alpha: 0.6),
                    strokeWidth: 1.5,
                    dashArray: [8, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: theme.textTheme.labelSmall!.copyWith(
                        color: colorScheme.error,
                      ),
                      labelResolver: (_) =>
                          'Target ${targetAmountCents!.toCurrency()}',
                    ),
                  ),
                ])
              : null,
          lineBarsData: [
            // p10 — bottom boundary (invisible, used for fill)
            _bandLine(spotsP10, Colors.transparent),
            // p90 — top boundary (invisible, used for fill)
            _bandLine(spotsP90, Colors.transparent),
            // p50 — median line (prominent)
            LineChartBarData(
              spots: spotsP50,
              isCurved: true,
              color: primaryColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
            ),
            // p25 — inner band boundary (invisible)
            _bandLine(spotsP25, Colors.transparent),
            // p75 — inner band boundary (invisible)
            _bandLine(spotsP75, Colors.transparent),
          ],
          betweenBarsData: [
            // Outer band: p10–p90
            BetweenBarsData(
              fromIndex: 0,
              toIndex: 1,
              color: bandColorOuter,
            ),
            // Inner band: p25–p75
            BetweenBarsData(
              fromIndex: 3,
              toIndex: 4,
              color: bandColorInner,
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _toSpots(List<int> values) {
    return List.generate(values.length, (i) {
      return FlSpot(i.toDouble(), values[i].toDouble());
    });
  }

  LineChartBarData _bandLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 0,
      dotData: const FlDotData(show: false),
    );
  }

  double _xInterval(int count) {
    if (count <= 10) return 1;
    if (count <= 20) return 5;
    if (count <= 40) return 10;
    return (count / 5).roundToDouble();
  }

  /// Compact currency: $1.2M, $500K, $50K
  static String _compactCurrency(int cents) {
    final dollars = cents / 100;
    if (dollars >= 1000000) {
      return '\$${(dollars / 1000000).toStringAsFixed(1)}M';
    }
    if (dollars >= 1000) {
      return '\$${(dollars / 1000).toStringAsFixed(0)}K';
    }
    return '\$${dollars.toStringAsFixed(0)}';
  }
}
