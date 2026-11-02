import 'package:flutter/material.dart';

import '../../domain/models/stats_summary.dart';
import '../utils/stats_formatters.dart';

/// Displays the key high-level waste statistics in a card grid.
class SummaryCardsGrid extends StatelessWidget {
  const SummaryCardsGrid({
    super.key,
    required this.summary,
  });

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 500 ? 1.4 : 1.15,
          children: [
            _SummaryStatCard(
              title: 'Rescued Items',
              value: '${summary.rescuedUnits}',
              subtitle: summary.usedLateUnits > 0
                  ? '${summary.usedLateUnits} used after expiry'
                  : 'Used before expiry',
              icon: Icons.verified_outlined,
              iconColor: Colors.green,
              tooltip: 'Used on or before expiry date',
            ),
            _SummaryStatCard(
              title: 'Wasted Items',
              value: '${summary.wastedUnits}',
              subtitle: 'Marked as spoiled/wasted',
              icon: Icons.delete_outline,
              iconColor: Colors.redAccent,
              tooltip: 'Items marked as wasted',
            ),
            _SummaryStatCard(
              title: 'Waste Rate',
              value: StatsFormatters.formatPercent(summary.wasteRate),
              subtitle: summary.wasteRate == null
                  ? 'No consumption data'
                  : 'Wasted / (Used + Wasted)',
              icon: Icons.pie_chart_outline,
              iconColor: Colors.deepOrange,
              tooltip: 'Percentage of resolved items that were wasted',
            ),
            _SummaryStatCard(
              title: 'Clean Streak',
              value: summary.daysSinceLastWaste != null
                  ? '${summary.daysSinceLastWaste} days'
                  : 'No waste',
              subtitle: summary.daysSinceLastWaste != null
                  ? 'Since last wasted item'
                  : 'No waste recorded yet',
              icon: Icons.local_fire_department_outlined,
              iconColor: Colors.amber.shade800,
              tooltip: 'Days since the last recorded wasted item',
            ),
            _SummaryStatCard(
              title: 'Value Used',
              value: StatsFormatters.formatPaise(summary.valueUsedPaise),
              subtitle: summary.usedCoverageNote,
              icon: Icons.currency_rupee,
              iconColor: Colors.teal,
              tooltip: 'Total value of items consumed',
            ),
            _SummaryStatCard(
              title: 'Value Wasted',
              value: StatsFormatters.formatPaise(summary.valueWastedPaise),
              subtitle: summary.wastedCoverageNote,
              icon: Icons.money_off_outlined,
              iconColor: Colors.red.shade700,
              tooltip: 'Total value of items wasted',
            ),
          ],
        );
      },
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.tooltip,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final header = Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (tooltip != null)
          Tooltip(
            message: tooltip!,
            triggerMode: TooltipTriggerMode.tap,
            child: Icon(
              Icons.info_outline,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
      ],
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            header,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
