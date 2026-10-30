import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../../shopping/domain/repositories/shopping_repository.dart';
import '../../domain/constants/recipe_matcher_constants.dart';
import '../../domain/models/detail_ingredient_item.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_detail_match_result.dart';
import '../../domain/models/recipe_ingredient_status.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/repositories/staples_repository.dart';
import '../../domain/services/ingredient_normalizer.dart';
import '../cubit/recipe_detail_cubit.dart';
import '../cubit/recipe_detail_state.dart';

class RecipeDetailPage extends StatelessWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context) {
    StaplesRepository? staplesRepo;
    try {
      staplesRepo = context.read<StaplesRepository>();
    } catch (_) {
      staplesRepo = null;
    }

    ShoppingRepository? shoppingRepo;
    try {
      shoppingRepo = context.read<ShoppingRepository>();
    } catch (_) {
      shoppingRepo = null;
    }

    return BlocProvider(
      create: (context) => RecipeDetailCubit(
        recipeRepository: context.read<RecipeRepository>(),
        pantryRepository: context.read<PantryRepository>(),
        staplesRepository: staplesRepo,
        shoppingRepository: shoppingRepo,
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
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          final detailMatch = state.detailMatch;

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
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
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
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
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
                            avatar:
                                const Icon(Icons.category_outlined, size: 16),
                            label: Text(recipe.category),
                          ),
                          Chip(
                            avatar: const Icon(Icons.public_outlined, size: 16),
                            label: Text(recipe.area),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Live Match Summary Header Card
                      if (detailMatch != null) ...[
                        _buildLiveSummaryCard(context, detailMatch, theme),
                        const SizedBox(height: 16),
                      ],

                      // Ingredients List with Pantry Badges & User Marks
                      Text(
                        'Ingredients (${recipe.ingredients.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (detailMatch != null)
                        _buildIngredientsList(
                            context, detailMatch.items, theme)
                      else
                        _buildFallbackIngredientsList(recipe, theme),

                      // Caption for ephemeral manual marks
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                        child: Text(
                          'Marks applied here are temporary and apply only to this recipe. They will be reset when you leave this screen.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Step 7 Shopping List Live Hook
                      FilledButton.tonalIcon(
                        key: const Key('add_missing_to_shopping_list_hook'),
                        icon: const Icon(Icons.playlist_add),
                        label: const Text(
                          'Add missing ingredients to shopping list',
                        ),
                        onPressed: (detailMatch != null &&
                                detailMatch.missingCount > 0)
                            ? () async {
                                final count = await context
                                    .read<RecipeDetailCubit>()
                                    .addMissingToShoppingList();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        count == 1
                                            ? 'Added 1 item to shopping list'
                                            : 'Added $count items to shopping list',
                                      ),
                                      action: SnackBarAction(
                                        label: 'View list',
                                        onPressed: () =>
                                            context.push('/shopping'),
                                      ),
                                    ),
                                  );
                                }
                              }
                            : null,
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

  Widget _buildLiveSummaryCard(
    BuildContext context,
    RecipeDetailMatchResult result,
    ThemeData theme,
  ) {
    final matchPercent = (result.matchPercentage * 100).round();

    return Container(
      key: const Key('match_header_card'),
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
                '$matchPercent% Match',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${result.availableCount}/${result.totalIngredients} available',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Live summary: e.g. "You have 7 of 9 ingredients (includes your manual marks)"
          Text(
            result.summaryText,
            key: const Key('header_summary_text'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          // Missing summary: e.g. "2 missing: onion, garlic" or "All ingredients available!"
          Text(
            result.missingSummaryText,
            key: const Key('header_missing_summary_text'),
            style: TextStyle(
              fontSize: 12,
              color: result.missingCount > 0
                  ? theme.colorScheme.error
                  : Colors.green.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (result.expiringItemsUsed.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Uses ${result.expiringItemsUsed.length} items expiring soon: '
              '${result.expiringItemsUsed.map((i) => i.name).join(', ')}',
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
    BuildContext context,
    List<DetailIngredientItem> items,
    ThemeData theme,
  ) {
    final cubit = context.read<RecipeDetailCubit>();

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
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final ingName = item.ingredient.name;

          return ListTile(
            key: Key('ingredient_tile_$ingName'),
            dense: true,
            leading: _buildLeadingToggle(context, item, cubit),
            title: Text(
              ingName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: item.isAvailable ? null : null,
              ),
            ),
            subtitle: item.ingredient.measure.isNotEmpty
                ? Text(item.ingredient.measure)
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusBadge(item, theme),
                if (_canAddToPantry(item)) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: Key('add_to_pantry_$ingName'),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: 'Add to pantry inventory',
                    onPressed: () async {
                      final now = DateTime.now();
                      final guessed =
                          IngredientNormalizer.guessCategory(item.ingredient.name);
                      final prefilled = PantryItem(
                        name: item.ingredient.name,
                        category: guessed.label,
                        quantity: 1,
                        expiryDate: now.add(const Duration(days: 7)),
                        addedAt: now,
                      );
                      await context.push('/item/new', extra: prefilled);
                      if (context.mounted) {
                        cubit.refresh();
                      }
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Whether this row is a non-pantry, non-staple row eligible for "Add to pantry".
  bool _canAddToPantry(DetailIngredientItem item) {
    if (item.status == RecipeIngredientStatus.inPantry) return false;
    final isDocumentedStaple =
        IngredientNormalizer.isStaple(item.ingredient.name);
    return !isDocumentedStaple;
  }

  Widget _buildLeadingToggle(
    BuildContext context,
    DetailIngredientItem item,
    RecipeDetailCubit cubit,
  ) {
    if (item.status == RecipeIngredientStatus.inPantry) {
      return Icon(
        Icons.check_circle,
        color: Colors.green.shade700,
        size: 22,
      );
    }

    // Staple row
    final isDocumentedStaple =
        IngredientNormalizer.isStaple(item.ingredient.name);
    if (isDocumentedStaple) {
      return Tooltip(
        message: item.isStapleAvailable
            ? 'Untick if you don\'t have this staple (remembers globally)'
            : 'Tick if you have this staple (restores globally)',
        child: Checkbox(
          key: Key('checkbox_${item.ingredient.name}'),
          value: item.isStapleAvailable,
          onChanged: (_) {
            cubit.toggleStapleAvailability(item.ingredient.name);
          },
        ),
      );
    }

    // Non-staple missing row with per-recipe "I have this" toggle
    return Tooltip(
      message: 'I have this (for this recipe only)',
      child: Checkbox(
        key: Key('checkbox_${item.ingredient.name}'),
        value: item.isUserMarkedAvailable,
        onChanged: (_) {
          cubit.toggleUserMark(item.ingredient.name);
        },
      ),
    );
  }

  Widget _buildStatusBadge(DetailIngredientItem item, ThemeData theme) {
    if (item.status == RecipeIngredientStatus.inPantry) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade700),
        ),
        child: Text(
          'In pantry',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade900,
          ),
        ),
      );
    }

    final isDocumentedStaple =
        IngredientNormalizer.isStaple(item.ingredient.name);

    if (isDocumentedStaple && item.isStapleAvailable) {
      // Documented staple, assumed available
      // STAPLES MUST NEVER BE LABELLED "In pantry"
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.kitchen_outlined, size: 14, color: Colors.teal.shade800),
            const SizedBox(width: 4),
            Text(
              'Usually in every kitchen',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
          ],
        ),
      );
    }

    if (item.isUserMarked) {
      // User manually ticked this non-pantry item
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade800),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 14, color: Colors.amber.shade900),
            const SizedBox(width: 4),
            Text(
              'You marked: have it',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade900,
              ),
            ),
          ],
        ),
      );
    }

    // Missing (unmarked non-staple, or unavailable staple)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        'Missing',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildFallbackIngredientsList(Recipe recipe, ThemeData theme) {
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
          final ing = recipe.ingredients[index];
          return ListTile(
            dense: true,
            title: Text(ing.name),
            subtitle: ing.measure.isNotEmpty ? Text(ing.measure) : null,
          );
        },
      ),
    );
  }
}
