import '../../../inventory/domain/models/pantry_item.dart';
import '../constants/recipe_matcher_constants.dart';
import '../models/recipe.dart';
import '../models/recipe_ingredient.dart';
import '../models/recipe_match.dart';
import 'ingredient_normalizer.dart';

/// Pure Dart matching and ranking engine that pairs available pantry stock
/// with candidate recipes.
class RecipeMatcher {
  const RecipeMatcher();

  /// Evaluates and ranks [candidateRecipes] against current [pantryItems] relative to [now].
  ///
  /// Ranking Formula:
  /// - Base Score = (matchPercentage * 100) - (missingNonStaples * 5)
  /// - Expiring Item Urgency Boost:
  ///   - Expiring today or tomorrow (<= 1 day remaining): +500 points per item
  ///   - Expiring in 2-3 days: +250 points per item
  /// - Tie-breaker: Alphabetical recipe name and id for deterministic ordering.
  static List<RecipeMatch> matchAndRank({
    required List<PantryItem> pantryItems,
    required List<Recipe> candidateRecipes,
    required DateTime now,
  }) {
    if (candidateRecipes.isEmpty) return const [];

    final todayStart = DateTime(now.year, now.month, now.day);
    final expiringCutoff = todayStart.add(const Duration(days: 3, hours: 23, minutes: 59));

    // Pre-normalize all pantry items with their expiry status
    final normalizedPantry = <_PantryEntry>[];
    for (final item in pantryItems) {
      if (item.quantity <= 0) continue;
      final keyword = IngredientNormalizer.normalize(item.name, category: item.category);
      if (keyword.isNotEmpty) {
        final isExpiringSoon = !item.expiryDate.isBefore(todayStart) &&
            item.expiryDate.isBefore(expiringCutoff);
        normalizedPantry.add(_PantryEntry(
          item: item,
          normalizedKeyword: keyword,
          isExpiringSoon: isExpiringSoon,
        ));
      }
    }

    final matches = <RecipeMatch>[];

    for (final recipe in candidateRecipes) {
      final matchedIngredients = <RecipeIngredient>[];
      final missingIngredients = <RecipeIngredient>[];
      final matchedPantryItems = <PantryItem>{};

      int totalNonStaples = 0;
      int matchedNonStaples = 0;

      for (final ingredient in recipe.ingredients) {
        final rawName = ingredient.name.trim();
        if (rawName.isEmpty) continue;

        final isStaple = IngredientNormalizer.isStaple(rawName);
        if (!isStaple) {
          totalNonStaples++;
        }

        final normalizedRecipeIng = IngredientNormalizer.normalize(rawName);

        // Check if any pantry item satisfies this recipe ingredient
        _PantryEntry? foundEntry;
        for (final entry in normalizedPantry) {
          if (_isMatch(entry.normalizedKeyword, normalizedRecipeIng)) {
            foundEntry = entry;
            break;
          }
        }

        if (foundEntry != null) {
          matchedIngredients.add(ingredient);
          matchedPantryItems.add(foundEntry.item);
          if (!isStaple) {
            matchedNonStaples++;
          }
        } else if (isStaple) {
          // Staples not explicitly in pantry are assumed available
          matchedIngredients.add(ingredient);
        } else {
          missingIngredients.add(ingredient);
        }
      }

      final double matchPercentage = totalNonStaples == 0
          ? 1.0
          : (matchedNonStaples / totalNonStaples).clamp(0.0, 1.0);

      // Determine expiring pantry items utilized in this recipe
      final expiringUsed = matchedPantryItems.where((item) {
        return !item.expiryDate.isBefore(todayStart) &&
            item.expiryDate.isBefore(expiringCutoff);
      }).toList();

      // Compute composite ranking score
      double score = (matchPercentage * 100) - (missingIngredients.length * 5);

      for (final expiringItem in expiringUsed) {
        final daysRemaining = expiringItem.expiryDate.difference(todayStart).inDays;
        if (daysRemaining <= 1) {
          score += 500.0; // Urgently expiring today or tomorrow
        } else {
          score += 250.0; // Expiring within 2-3 days
        }
      }

      matches.add(
        RecipeMatch(
          recipe: recipe,
          matchedIngredients: List.unmodifiable(matchedIngredients),
          missingIngredients: List.unmodifiable(missingIngredients),
          matchPercentage: matchPercentage,
          expiringItemsUsed: List.unmodifiable(expiringUsed),
          score: score,
        ),
      );
    }

    // Sort descending by score, tie-break by name and ID
    matches.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) return scoreComparison;

      final matchComparison = b.matchPercentage.compareTo(a.matchPercentage);
      if (matchComparison != 0) return matchComparison;

      final nameComparison = a.recipe.name.compareTo(b.recipe.name);
      if (nameComparison != 0) return nameComparison;

      return a.recipe.id.compareTo(b.recipe.id);
    });

    return matches;
  }

  /// Best-effort vegetarian filter.
  ///
  /// Checks whether a recipe avoids known meat/fish categories and ingredients.
  /// Note: This is an automated heuristic and cannot guarantee religious or allergen purity.
  static bool isVegetarian(Recipe recipe) {
    final cat = recipe.category.toLowerCase().trim();
    if (RecipeMatcherConstants.nonVegetarianCategories.contains(cat)) {
      return false;
    }

    for (final ingredient in recipe.ingredients) {
      final normalized = IngredientNormalizer.normalize(ingredient.name);
      final rawLower = ingredient.name.toLowerCase();

      for (final meatKeyword in RecipeMatcherConstants.meatKeywords) {
        if (normalized == meatKeyword ||
            rawLower.contains(meatKeyword) ||
            normalized.split(' ').contains(meatKeyword)) {
          return false;
        }
      }
    }

    return true;
  }

  static bool _isMatch(String pantryKeyword, String recipeIngredientKeyword) {
    if (pantryKeyword.isEmpty || recipeIngredientKeyword.isEmpty) return false;

    if (pantryKeyword == recipeIngredientKeyword) return true;

    // Substring boundary matching
    if (pantryKeyword.length >= 3 && recipeIngredientKeyword.contains(pantryKeyword)) {
      return true;
    }
    if (recipeIngredientKeyword.length >= 3 &&
        pantryKeyword.contains(recipeIngredientKeyword)) {
      return true;
    }

    return false;
  }
}

class _PantryEntry {
  const _PantryEntry({
    required this.item,
    required this.normalizedKeyword,
    required this.isExpiringSoon,
  });

  final PantryItem item;
  final String normalizedKeyword;
  final bool isExpiringSoon;
}

