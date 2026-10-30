import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/recipe_match.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.match});

  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = match.recipe;
    final matchPercent = (match.matchPercentage * 100).round();
    final totalIngredients = match.matchedCount + match.missingCount;

    Color matchColor;
    if (matchPercent >= 80) {
      matchColor = Colors.green.shade700;
    } else if (matchPercent >= 50) {
      matchColor = Colors.amber.shade800;
    } else {
      matchColor = theme.colorScheme.secondary;
    }

    return Card(
      key: Key('recipe_card_${recipe.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: match.usesExpiringItems
            ? BorderSide(color: Colors.orange.shade600, width: 2)
            : BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image with overlay chips
            Stack(
              children: [
                if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      recipe.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.restaurant, size: 48),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.restaurant, size: 48),
                    ),
                  ),

                // Match Percentage Badge (top right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: matchColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      '$matchPercent% Match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // Area / Cuisine chip (top left)
                if (recipe.area.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recipe.area,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipe Name
                  Text(
                    recipe.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Category & Ingredient availability
                  Row(
                    children: [
                      Text(
                        recipe.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(' • '),
                      Text(
                        '${match.matchedCount}/$totalIngredients in pantry',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: matchColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Expiring Soon priority banner
                  if (match.usesExpiringItems) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_bottom_rounded,
                              size: 14, color: Colors.orange.shade900),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Uses ${match.expiringItemsUsed.length} expiring soon: '
                              '${match.expiringItemsUsed.map((i) => i.name).join(', ')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

