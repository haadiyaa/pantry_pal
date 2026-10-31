import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../inventory/domain/models/pantry_category.dart';
import '../../domain/models/category_stat.dart';
import '../utils/stats_formatters.dart';

/// Donut chart showing the breakdown of wasted food across categories.
class CategoryWasteDonutChart extends StatelessWidget {
  const CategoryWasteDonutChart({
    super.key,
    required this.categories,
  });

  final List<CategoryStat> categories;

  static Color getCategoryColor(PantryCategory category) {
    switch (category) {
      case PantryCategory.dairy:
        return Colors.blue.shade600;
      case PantryCategory.vegetables:
        return Colors.green.shade600;
      case PantryCategory.fruits:
        return Colors.orange.shade700;
      case PantryCategory.meatAndFish:
        return Colors.red.shade700;
      case PantryCategory.grains:
        return Colors.amber.shade800;
      case PantryCategory.snacks:
        return Colors.purple.shade600;
      case PantryCategory.beverages:
        return Colors.teal.shade600;
      case PantryCategory.frozen:
        return Colors.cyan.shade700;
      case PantryCategory.other:
        return Colors.blueGrey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (categories.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No wasted food recorded in this period! 🎉'),
          ),
        ),
      );
    }

    final catList = categories
        .map((c) => '${c.category} ${c.percentage.toStringAsFixed(1)}% (${c.wastedUnits} units)')
        .join(', ');
    final semanticSummary = 'Donut chart of wasted food by category: $catList';

    return Semantics(
      label: semanticSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Waste by Category',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: categories.map((stat) {
                      final category = PantryCategory.fromString(stat.category);
                      final color = getCategoryColor(category);
                      final showTitle = stat.percentage >= 8.0;

                      return PieChartSectionData(
                        color: color,
                        value: stat.wastedUnits.toDouble(),
                        title: showTitle ? '${stat.percentage.toStringAsFixed(0)}%' : '',
                        radius: 30,
                        titleStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: categories.map((stat) {
                    final category = PantryCategory.fromString(stat.category);
                    final color = getCategoryColor(category);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(category.icon, size: 16, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${stat.wastedUnits} u (${stat.percentage.toStringAsFixed(0)}%)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (stat.totalPricePaise > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              StatsFormatters.formatPaise(stat.totalPricePaise),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
