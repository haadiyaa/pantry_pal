import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../models/recipe.dart';

/// Result container returned when fetching recipe suggestions.
class RecipeQueryResult extends Equatable {
  const RecipeQueryResult({
    required this.recipes,
    this.isStale = false,
    this.isPartial = false,
    this.failedIngredients = const [],
  });

  final List<Recipe> recipes;

  /// True if network was unavailable and results were served from local cache.
  final bool isStale;

  /// True if one or more ingredient queries failed but partial results were returned.
  final bool isPartial;

  /// The list of ingredient keywords whose network requests failed.
  final List<String> failedIngredients;

  @override
  List<Object?> get props => [recipes, isStale, isPartial, failedIngredients];
}

/// Result container returned when fetching a single recipe's full details.
class RecipeDetailResult extends Equatable {
  const RecipeDetailResult({
    this.recipe,
    this.isStale = false,
  });

  final Recipe? recipe;
  final bool isStale;

  @override
  List<Object?> get props => [recipe, isStale];
}

/// Abstract contract for fetching and caching recipe suggestions and details.
abstract class RecipeRepository {
  /// Fetches candidate recipes based on the user's pantry items.
  Future<RecipeQueryResult> getRecipeSuggestions({
    required List<PantryItem> pantryItems,
    int ingredientQueryCap = 6,
    int maxCandidateRecipes = 15,
    bool forceRefresh = false,
  });

  /// Fetches full recipe details for [id], leveraging local SQLite cache.
  Future<RecipeDetailResult> getRecipeById(
    String id, {
    bool forceRefresh = false,
  });

  /// Prunes stale cache entries older than 30 days.
  Future<void> cleanOldCache();
}

