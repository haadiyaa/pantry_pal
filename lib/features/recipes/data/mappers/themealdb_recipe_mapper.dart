import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_ingredient.dart';
import '../../domain/models/recipe_summary.dart';

/// Pure mapper that transforms raw TheMealDB JSON dictionaries into immutable
/// domain models.
class TheMealDbRecipeMapper {
  const TheMealDbRecipeMapper._();

  /// Maps a meal details dictionary into a [Recipe].
  static Recipe? fromMealJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;

    final id = json['idMeal']?.toString() ?? '';
    final name = json['strMeal']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty) return null;

    final category = json['strCategory']?.toString() ?? 'Other';
    final area = json['strArea']?.toString() ?? 'International';
    final instructions = json['strInstructions']?.toString() ?? '';
    final imageUrl = json['strMealThumb']?.toString();
    final youtubeUrl = json['strYoutube']?.toString();

    final ingredients = <RecipeIngredient>[];

    // TheMealDB provides up to 20 ordered ingredient and measure slots
    for (var i = 1; i <= 20; i++) {
      final ingredientKey = 'strIngredient$i';
      final measureKey = 'strMeasure$i';

      final rawIngredient = json[ingredientKey]?.toString().trim() ?? '';
      final rawMeasure = json[measureKey]?.toString().trim() ?? '';

      // Skip empty, null, or whitespace-only slots
      if (rawIngredient.isNotEmpty) {
        ingredients.add(
          RecipeIngredient(
            name: rawIngredient,
            measure: rawMeasure,
          ),
        );
      }
    }

    return Recipe(
      id: id,
      name: name,
      category: category,
      area: area,
      instructions: instructions,
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
      youtubeUrl: (youtubeUrl != null && youtubeUrl.isNotEmpty) ? youtubeUrl : null,
      ingredients: List.unmodifiable(ingredients),
    );
  }

  /// Maps an item from `filter.php` into a [RecipeSummary].
  static RecipeSummary? fromFilterJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;

    final id = json['idMeal']?.toString() ?? '';
    final name = json['strMeal']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty) return null;

    final imageUrl = json['strMealThumb']?.toString();

    return RecipeSummary(
      id: id,
      name: name,
      imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
    );
  }
}

