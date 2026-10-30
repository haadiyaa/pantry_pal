import '../../../inventory/domain/models/pantry_item.dart';
import '../../../recipes/domain/models/recipe.dart';
import '../../../recipes/domain/models/recipe_detail_match_result.dart';
import '../../../recipes/domain/services/ingredient_normalizer.dart';
import '../../../recipes/domain/services/recipe_matcher.dart';
import '../models/shopping_item.dart';
import '../models/shopping_source_type.dart';

/// Pure functional service that converts missing recipe ingredients into shopping items.
/// Has zero Flutter framework dependencies.
class ShoppingFromRecipe {
  const ShoppingFromRecipe._();

  /// Extracts missing ingredients from a [RecipeDetailMatchResult] into [ShoppingItem]s.
  ///
  /// Matching rules:
  /// - Real pantry items: EXCLUDED.
  /// - Assumed available kitchen staples: EXCLUDED.
  /// - Ingredients ticked "I have this": EXCLUDED.
  /// - Kitchen staples the user marked unavailable: INCLUDED.
  /// - Non-staple missing ingredients: INCLUDED.
  /// - Recipe name is set as the source label.
  /// - Duplicate ingredient references within the same recipe are merged.
  static List<ShoppingItem> extractMissing({
    required RecipeDetailMatchResult matchResult,
    required String recipeName,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final items = <ShoppingItem>[];

    for (final detailItem in matchResult.items) {
      if (!detailItem.isMissing) continue;

      final rawName = detailItem.ingredient.name.trim();
      if (rawName.isEmpty) continue;

      final normalized = IngredientNormalizer.normalize(rawName);
      final key = normalized.isNotEmpty ? normalized : rawName.toLowerCase();
      final guessedCat = IngredientNormalizer.guessCategory(rawName).label;

      items.add(
        ShoppingItem(
          name: rawName,
          normalizedName: key,
          quantity: 1,
          category: guessedCat,
          isBought: false,
          sourceType: ShoppingSourceType.recipe,
          sourceLabel: recipeName,
          addedAt: timestamp,
        ),
      );
    }

    // Merge duplicates if the recipe lists the same normalized ingredient twice
    final merged = <String, ShoppingItem>{};
    for (final item in items) {
      if (merged.containsKey(item.normalizedName)) {
        final existing = merged[item.normalizedName]!;
        merged[item.normalizedName] = existing.copyWith(
          quantity: existing.quantity + item.quantity,
        );
      } else {
        merged[item.normalizedName] = item;
      }
    }

    return merged.values.toList();
  }

  /// Convenience helper evaluating a [Recipe] directly through [RecipeMatcher]
  /// and returning the missing shopping items.
  static List<ShoppingItem> fromRecipe({
    required Recipe recipe,
    required List<PantryItem> pantryItems,
    Set<String> unavailableStaples = const {},
    Set<String> userMarkedAvailable = const {},
    required DateTime now,
  }) {
    final detailMatch = RecipeMatcher.evaluateDetail(
      recipe: recipe,
      pantryItems: pantryItems,
      unavailableStaples: unavailableStaples,
      userMarkedAvailable: userMarkedAvailable,
      now: now,
    );
    return extractMissing(
      matchResult: detailMatch,
      recipeName: recipe.name,
      now: now,
    );
  }
}

