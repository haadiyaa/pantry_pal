import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/models/stats_period.dart';
import '../../domain/models/time_bucket.dart';

/// Grouped bar chart comparing Used vs Wasted items across continuous time buckets.
class UsedVsWastedBarChart extends StatelessWidget {
  const UsedVsWastedBarChart({
    super.key,
    required this.buckets,
    required this.period,
  });

  final List<TimeBucket> buckets;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (buckets.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('No timeline data available.'),
        ),
      );
    }

    // Determine max value for clean Y-axis headroom
    final maxCount = buckets.fold<int>(
      0,
      (curr, b) => max(curr, max(b.usedCount, b.wastedCount)),
    );
    final maxY = maxCount == 0 ? 5.0 : (maxCount * 1.25).ceilToDouble();

    // Generate accessibility text summary
    final totalUsed = buckets.fold<int>(0, (curr, b) => curr + b.usedCount);
    final totalWasted = buckets.fold<int>(0, (curr, b) => curr + b.wastedCount);
    var peakWasted = 0;
    var peakWastedBucket = '';
    for (final b in buckets) {
      if (b.wastedCount > peakWasted) {
        peakWasted = b.wastedCount;
        peakWastedBucket = b.label;
      }
    }

    final semanticSummary = 'Bar chart showing used versus wasted items for ${period.label}. '
        'Total used: $totalUsed, total wasted: $totalWasted. '
        '${peakWasted > 0 ? "Highest waste was $peakWasted items in $peakWastedBucket." : "No wasted items in this period."}';

    final usedColor = Colors.green.shade600;
    final wastedColor = Colors.redAccent.shade400;

    return Semantics(
      label: semanticSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Activity Over Time',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _ChartLegendItem(color: usedColor, label: 'Used'),
              const SizedBox(width: 12),
              _ChartLegendItem(color: wastedColor, label: 'Wasted'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final bucket = buckets[group.x.toInt()];
                      final isUsed = rodIndex == 0;
                      return BarTooltipItem(
                        '${bucket.label}\n',
                        TextStyle(
                          color: colorScheme.onInverseSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: isUsed
                                ? 'Used: ${rod.toY.toInt()}'
                                : 'Wasted: ${rod.toY.toInt()}',
                            style: TextStyle(
                              color: isUsed ? Colors.lightGreenAccent : Colors.red.shade200,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY > 5 ? (maxY / 4).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value > maxY) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= buckets.length) {
                          return const SizedBox.shrink();
                        }
                        // Skip labels when there are many bars to avoid overcrowding
                        if (buckets.length > 7 &&
                            index % (buckets.length > 14 ? 3 : 2) != 0 &&
                            index != buckets.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            buckets[index].label,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(buckets.length, (index) {
                  final b = buckets[index];
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: b.usedCount.toDouble(),
                        color: usedColor,
                        width: buckets.length > 10 ? 8 : 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: b.wastedCount.toDouble(),
                        color: wastedColor,
                        width: buckets.length > 10 ? 8 : 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
