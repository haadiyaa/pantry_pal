import 'package:flutter/material.dart';

import '../../../recipes/domain/services/ingredient_normalizer.dart';
import '../../domain/models/item_stat.dart';
import '../utils/stats_formatters.dart';

/// Displays top 5 wasted and top 5 used items with units and category indicators.
class TopItemsSection extends StatelessWidget {
  const TopItemsSection({
    super.key,
    required this.topWastedItems,
    required this.topUsedItems,
  });

  final List<ItemStat> topWastedItems;
  final List<ItemStat> topUsedItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemListCard(
          title: 'Most Wasted Items',
          subtitle: 'Items spoiled or discarded most frequently',
          icon: Icons.delete_sweep_outlined,
          iconColor: Colors.redAccent,
          items: topWastedItems,
          emptyMessage: 'No wasted items to display.',
        ),
        const SizedBox(height: 16),
        _ItemListCard(
          title: 'Most Used Items',
          subtitle: 'Your pantry staples and household favorites',
          icon: Icons.thumb_up_alt_outlined,
          iconColor: Colors.green,
          items: topUsedItems,
          emptyMessage: 'No consumed items recorded yet.',
        ),
      ],
    );
  }
}

class _ItemListCard extends StatelessWidget {
  const _ItemListCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.emptyMessage,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<ItemStat> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => Divider(
                  height: 12,
                  thickness: 0.5,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final category = IngredientNormalizer.guessCategory(item.name);

                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        category.icon,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              category.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.units} ${item.units == 1 ? 'unit' : 'units'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.totalPricePaise > 0)
                            Text(
                              StatsFormatters.formatPaise(item.totalPricePaise),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
