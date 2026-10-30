import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../domain/constants/recipe_matcher_constants.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../bloc/recipe_suggestions_bloc.dart';
import '../bloc/recipe_suggestions_event.dart';
import '../bloc/recipe_suggestions_state.dart';
import '../widgets/recipe_card.dart';

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RecipeSuggestionsBloc(
        pantryRepository: context.read<PantryRepository>(),
        recipeRepository: context.read<RecipeRepository>(),
      )..add(const RecipeSuggestionsStarted()),
      child: const _RecipesView(),
    );
  }
}

class _RecipesView extends StatelessWidget {
  const _RecipesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<RecipeSuggestionsBloc>();

    return MultiBlocListener(
      listeners: [
        BlocListener<InventoryBloc, InventoryState>(
          listener: (context, inventoryState) {
            bloc.add(RecipeSuggestionsInventoryChanged(inventoryState.items));
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recipe Ideas'),
          actions: [
            IconButton(
              key: const Key('refresh_recipes_button'),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Recipes',
              onPressed: () => bloc.add(const RecipeSuggestionsRefreshed()),
            ),
          ],
        ),
        body: Column(
          children: [
            // Filter Bar
            const _FilterHeaderBar(),

            // Stale Cache / Partial Failure Notifications
            BlocBuilder<RecipeSuggestionsBloc, RecipeSuggestionsState>(
              buildWhen: (prev, curr) =>
                  prev.isStale != curr.isStale || prev.isPartial != curr.isPartial,
              builder: (context, state) {
                return Column(
                  children: [
                    if (state.isStale)
                      Container(
                        key: const Key('stale_cache_banner'),
                        color: theme.colorScheme.tertiaryContainer,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off,
                                size: 18,
                                color: theme.colorScheme.onTertiaryContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Showing saved results (Offline cache)',
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
                    if (state.isPartial)
                      Container(
                        key: const Key('partial_results_banner'),
                        color: Colors.amber.shade100,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.amber.shade900),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Some ingredient lookups timed out. Showing partial matches.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),

            // Main Body Content
            Expanded(
              child: BlocBuilder<RecipeSuggestionsBloc, RecipeSuggestionsState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state.isFailure) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                size: 64, color: theme.colorScheme.error),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to load recipes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.errorMessage ?? 'Please check your connection and try again.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const Key('retry_recipes_button'),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              onPressed: () =>
                                  bloc.add(const RecipeSuggestionsRetried()),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state.isEmptyPantry) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.kitchen_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'Your pantry is empty',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add ingredients to your pantry to see matched recipe suggestions.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const Key('add_pantry_items_button'),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Pantry Items'),
                              onPressed: () => context.go('/item/new'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final matches = state.filteredMatches;

                  if (matches.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 56,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No recipes match current filters',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try clearing vegetarian or expiring filters, or lower the match percentage.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              key: const Key('reset_filters_button'),
                              onPressed: () {
                                if (state.isVegetarianOnly) {
                                  bloc.add(const RecipeSuggestionsVegetarianToggled());
                                }
                                if (state.isExpiringOnly) {
                                  bloc.add(const RecipeSuggestionsExpiringOnlyToggled());
                                }
                                if (state.minMatchPercentage > 0.0) {
                                  bloc.add(const RecipeSuggestionsMinMatchChanged(0.0));
                                }
                              },
                              child: const Text('Reset All Filters'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      bloc.add(const RecipeSuggestionsRefreshed());
                    },
                    child: ListView.builder(
                      itemCount: matches.length + 1,
                      itemBuilder: (context, index) {
                        if (index == matches.length) {
                          return const _TheMealDbAttributionFooter();
                        }
                        return RecipeCard(match: matches[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterHeaderBar extends StatelessWidget {
  const _FilterHeaderBar();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<RecipeSuggestionsBloc>();

    return BlocBuilder<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      buildWhen: (prev, curr) =>
          prev.isVegetarianOnly != curr.isVegetarianOnly ||
          prev.isExpiringOnly != curr.isExpiringOnly ||
          prev.minMatchPercentage != curr.minMatchPercentage,
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                key: const Key('filter_vegetarian_chip'),
                avatar: const Icon(Icons.eco, size: 16),
                label: const Text('Vegetarian'),
                selected: state.isVegetarianOnly,
                onSelected: (_) =>
                    bloc.add(const RecipeSuggestionsVegetarianToggled()),
              ),
              const SizedBox(width: 8),
              FilterChip(
                key: const Key('filter_expiring_chip'),
                avatar: const Icon(Icons.hourglass_bottom, size: 16),
                label: const Text('Expiring soon only'),
                selected: state.isExpiringOnly,
                onSelected: (_) =>
                    bloc.add(const RecipeSuggestionsExpiringOnlyToggled()),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                key: const Key('min_match_any_chip'),
                label: const Text('Any Match'),
                selected: state.minMatchPercentage == 0.0,
                onSelected: (_) =>
                    bloc.add(const RecipeSuggestionsMinMatchChanged(0.0)),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                key: const Key('min_match_50_chip'),
                label: const Text('50%+'),
                selected: state.minMatchPercentage == 0.5,
                onSelected: (_) =>
                    bloc.add(const RecipeSuggestionsMinMatchChanged(0.5)),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                key: const Key('min_match_75_chip'),
                label: const Text('75%+'),
                selected: state.minMatchPercentage == 0.75,
                onSelected: (_) =>
                    bloc.add(const RecipeSuggestionsMinMatchChanged(0.75)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TheMealDbAttributionFooter extends StatelessWidget {
  const _TheMealDbAttributionFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: Text(
          RecipeMatcherConstants.theMealDbAttribution,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

