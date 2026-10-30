import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_summary.dart';

/// Contract for fetching recipe summaries and full details from a remote provider.
abstract class RecipeRemoteDataSource {
  /// Queries recipes that use the given canonical [ingredient].
  Future<List<RecipeSummary>> filterByIngredient(String ingredient);

  /// Retrieves complete recipe information for the specified [id].
  Future<Recipe?> lookupById(String id);

  /// Retrieves the raw JSON map for [id] to facilitate local caching.
  Future<Map<String, dynamic>?> lookupRawById(String id);
}

