import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../domain/constants/recipe_matcher_constants.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_match.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../cubit/recipe_detail_cubit.dart';
import '../cubit/recipe_detail_state.dart';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RecipeDetailCubit(
        recipeRepository: context.read<RecipeRepository>(),
        pantryRepository: context.read<PantryRepository>(),
      )..loadRecipe(recipeId),
      child: const _RecipeDetailView(),
    );
  }
}

class _RecipeDetailView extends StatelessWidget {
  const _RecipeDetailView();

  Future<void> _launchYouTube(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video player.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video URL.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlocBuilder<RecipeDetailCubit, RecipeDetailState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.isFailure || state.recipe == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage ?? 'Failed to load recipe details',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to Recipes'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final recipe = state.recipe!;
          final match = state.match;

          return CustomScrollView(
            slivers: [
              // Sliver App Bar with Media Image
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    recipe.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                    ),
                  ),
                  background: recipe.imageUrl != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              recipe.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.restaurant, size: 64),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withAlpha(50),
                                    Colors.transparent,
                                    Colors.black.withAlpha(180),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.restaurant, size: 64),
                        ),
                ),
              ),

              // Content Body
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Offline Stale Notice Banner
                      if (state.isStale) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_off,
                                  size: 16,
                                  color: theme.colorScheme.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Showing saved offline recipe details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Category and Area tags
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.category_outlined, size: 16),
                            label: Text(recipe.category),
                          ),
                          Chip(
                            avatar: const Icon(Icons.public_outlined, size: 16),
                            label: Text(recipe.area),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Pantry Match Header
                      if (match != null) ...[
                        _buildMatchHeaderCard(context, match, theme),
                        const SizedBox(height: 16),
                      ],

                      // Ingredients List with Pantry Badges
                      Text(
                        'Ingredients (${recipe.ingredients.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      _buildIngredientsList(recipe, match, theme),
                      const SizedBox(height: 16),

                      // Step 7 Shopping List Placeholder Hook
                      FilledButton.tonalIcon(
                        key: const Key('add_missing_to_shopping_list_hook'),
                        icon: const Icon(Icons.playlist_add),
                        label: const Text(
                          'Add missing ingredients to shopping list (Step 7)',
                        ),
                        // Explicitly disabled per Step 6 requirement: hook reserved for Step 7
                        onPressed: null,
                      ),
                      const SizedBox(height: 24),

                      // Preparation Instructions
                      Text(
                        'Instructions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.instructions,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      // YouTube Video Action
                      if (recipe.youtubeUrl != null &&
                          recipe.youtubeUrl!.isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('watch_youtube_video_button'),
                            icon: const Icon(Icons.play_circle_fill,
                                color: Colors.red),
                            label: const Text('Watch on YouTube'),
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: theme.colorScheme.onSurface,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () =>
                                _launchYouTube(context, recipe.youtubeUrl!),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Attribution Notice
                      Center(
                        child: Text(
                          RecipeMatcherConstants.theMealDbAttribution,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchHeaderCard(
    BuildContext context,
    RecipeMatch match,
    ThemeData theme,
  ) {
    final matchPercent = (match.matchPercentage * 100).round();
    final total = match.matchedCount + match.missingCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '$matchPercent% Pantry Match',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${match.matchedCount}/$total on hand',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          if (match.usesExpiringItems) ...[
            const SizedBox(height: 6),
            Text(
              'Consumes ${match.expiringItemsUsed.length} expiring items: '
              '${match.expiringItemsUsed.map((i) => i.name).join(', ')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIngredientsList(
    Recipe recipe,
    RecipeMatch? match,
    ThemeData theme,
  ) {
    final matchedNames = match != null
        ? match.matchedIngredients.map((i) => i.name.toLowerCase().trim()).toSet()
        : <String>{};

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recipe.ingredients.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ingredient = recipe.ingredients[index];
          final isInPantry =
              matchedNames.contains(ingredient.name.toLowerCase().trim());

          return ListTile(
            key: Key('ingredient_tile_${ingredient.name}'),
            dense: true,
            title: Text(
              ingredient.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: ingredient.measure.isNotEmpty
                ? Text(ingredient.measure)
                : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isInPantry
                    ? Colors.green.shade100
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInPantry ? Colors.green.shade700 : Colors.grey.shade400,
                ),
              ),
              child: Text(
                isInPantry ? 'In pantry' : 'Missing',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isInPantry
                      ? Colors.green.shade900
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
