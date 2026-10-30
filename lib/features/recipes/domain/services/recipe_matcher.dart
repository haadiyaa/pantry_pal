import '../../../inventory/domain/models/pantry_item.dart';
import '../constants/recipe_matcher_constants.dart';
import '../models/detail_ingredient_item.dart';
import '../models/recipe.dart';
import '../models/recipe_detail_match_result.dart';
import '../models/recipe_ingredient.dart';
import '../models/recipe_ingredient_status.dart';
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
    Set<String> unavailableStaples = const {},
  }) {
    if (candidateRecipes.isEmpty) return const [];

    final todayStart = DateTime(now.year, now.month, now.day);
    final expiringCutoff =
        todayStart.add(const Duration(days: 3, hours: 23, minutes: 59));

    // Pre-normalize all pantry items with their expiry status
    final normalizedPantry = <_PantryEntry>[];
    for (final item in pantryItems) {
      if (item.quantity <= 0) continue;
      final keyword =
          IngredientNormalizer.normalize(item.name, category: item.category);
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
      final stapleIngredients = <RecipeIngredient>[];
      final missingIngredients = <RecipeIngredient>[];
      final matchedPantryItems = <PantryItem>{};

      int totalNonStaples = 0;
      int matchedNonStaples = 0;

      for (final ingredient in recipe.ingredients) {
        final rawName = ingredient.name.trim();
        if (rawName.isEmpty) continue;

        final isStaple = IngredientNormalizer.isStaple(rawName);
        final normalizedRecipeIng = IngredientNormalizer.normalize(rawName);
        final isStapleUnavailable = isStaple &&
            _isStapleUnavailable(rawName, normalizedRecipeIng, unavailableStaples);

        if (!isStaple || isStapleUnavailable) {
          totalNonStaples++;
        }

        // Check if any real pantry item satisfies this recipe ingredient
        _PantryEntry? foundEntry;
        for (final entry in normalizedPantry) {
          if (_isMatch(entry.normalizedKeyword, normalizedRecipeIng)) {
            foundEntry = entry;
            break;
          }
        }

        if (foundEntry != null) {
          // Real pantry match
          matchedIngredients.add(ingredient);
          matchedPantryItems.add(foundEntry.item);
          if (!isStaple || isStapleUnavailable) {
            matchedNonStaples++;
          }
        } else if (isStaple) {
          if (isStapleUnavailable) {
            // User globally marked this staple as unavailable
            missingIngredients.add(ingredient);
          } else {
            // Assumed available staple: NEVER labelled or counted as InPantry
            stapleIngredients.add(ingredient);
          }
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
        final daysRemaining =
            expiringItem.expiryDate.difference(todayStart).inDays;
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
          stapleIngredients: List.unmodifiable(stapleIngredients),
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

  /// Evaluates detailed ingredient statuses, user marks, staple overrides, and
  /// live summary metrics for [recipe].
  static RecipeDetailMatchResult evaluateDetail({
    required Recipe recipe,
    required List<PantryItem> pantryItems,
    Set<String> unavailableStaples = const {},
    Set<String> userMarkedAvailable = const {},
    required DateTime now,
  }) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final expiringCutoff =
        todayStart.add(const Duration(days: 3, hours: 23, minutes: 59));

    // Pre-normalize pantry items
    final normalizedPantry = <_PantryEntry>[];
    for (final item in pantryItems) {
      if (item.quantity <= 0) continue;
      final keyword =
          IngredientNormalizer.normalize(item.name, category: item.category);
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

    final items = <DetailIngredientItem>[];
    final matchedPantryItems = <PantryItem>{};

    int inPantryCount = 0;
    int stapleCount = 0;
    int userMarkedCount = 0;
    int missingCount = 0;

    int totalRequired = 0;
    int availableRequired = 0;

    for (final ingredient in recipe.ingredients) {
      final rawName = ingredient.name.trim();
      if (rawName.isEmpty) continue;

      final normalized = IngredientNormalizer.normalize(rawName);
      final isStaple = IngredientNormalizer.isStaple(rawName);
      final isStapleUnavailable = isStaple &&
          _isStapleUnavailable(rawName, normalized, unavailableStaples);

      // Check if real pantry item matches
      _PantryEntry? foundEntry;
      for (final entry in normalizedPantry) {
        if (_isMatch(entry.normalizedKeyword, normalized)) {
          foundEntry = entry;
          break;
        }
      }

      if (foundEntry != null) {
        // Matched real pantry item
        items.add(
          DetailIngredientItem(
            ingredient: ingredient,
            status: RecipeIngredientStatus.inPantry,
            matchedPantryItem: foundEntry.item,
          ),
        );
        matchedPantryItems.add(foundEntry.item);
        inPantryCount++;
        totalRequired++;
        availableRequired++;
      } else if (isStaple) {
        if (isStapleUnavailable) {
          // Staple marked as unavailable by user -> status is missing
          final isMarked = userMarkedAvailable.contains(normalized) ||
              userMarkedAvailable.contains(rawName.toLowerCase());
          items.add(
            DetailIngredientItem(
              ingredient: ingredient,
              status: RecipeIngredientStatus.missing,
              isStapleAvailable: false,
              isUserMarkedAvailable: isMarked,
            ),
          );
          totalRequired++;
          if (isMarked) {
            userMarkedCount++;
            availableRequired++;
          } else {
            missingCount++;
          }
        } else {
          // Standard kitchen staple, assumed available
          items.add(
            DetailIngredientItem(
              ingredient: ingredient,
              status: RecipeIngredientStatus.staple,
              isStapleAvailable: true,
            ),
          );
          stapleCount++;
        }
      } else {
        // Non-staple missing from pantry
        final isMarked = userMarkedAvailable.contains(normalized) ||
            userMarkedAvailable.contains(rawName.toLowerCase());
        items.add(
          DetailIngredientItem(
            ingredient: ingredient,
            status: RecipeIngredientStatus.missing,
            isUserMarkedAvailable: isMarked,
          ),
        );
        totalRequired++;
        if (isMarked) {
          userMarkedCount++;
          availableRequired++;
        } else {
          missingCount++;
        }
      }
    }

    final double matchPercentage = totalRequired == 0
        ? 1.0
        : (availableRequired / totalRequired).clamp(0.0, 1.0);

    final availableCount = inPantryCount + stapleCount + userMarkedCount;
    final totalIngredients = items.length;
    final hasManualMarks = userMarkedCount > 0;

    final expiringUsed = matchedPantryItems.where((item) {
      return !item.expiryDate.isBefore(todayStart) &&
          item.expiryDate.isBefore(expiringCutoff);
    }).toList();

    // Grouping/Sorting: InPantry (1) -> User Marked (2) -> Staples (3) -> Missing (4)
    final sortedItems = List<DetailIngredientItem>.from(items)
      ..sort((a, b) {
        int rank(DetailIngredientItem i) {
          if (i.status == RecipeIngredientStatus.inPantry) return 1;
          if (i.isUserMarked) return 2;
          if (i.isAvailableStaple) return 3;
          return 4; // Missing (unmarked non-staple or unavailable staple)
        }

        final rankComparison = rank(a).compareTo(rank(b));
        if (rankComparison != 0) return rankComparison;
        return a.ingredient.name.compareTo(b.ingredient.name);
      });

    final missingItems =
        sortedItems.where((i) => i.isMissing).map((i) => i.ingredient.name).toList();

    final missingSummary = missingItems.isEmpty
        ? 'All ingredients available!'
        : '${missingItems.length} missing: ${missingItems.take(3).join(', ')}${missingItems.length > 3 ? '...' : ''}';

    final summary = hasManualMarks
        ? 'You have $availableCount of $totalIngredients ingredients (includes your manual marks)'
        : 'You have $availableCount of $totalIngredients ingredients';

    return RecipeDetailMatchResult(
      items: List.unmodifiable(sortedItems),
      totalIngredients: totalIngredients,
      availableCount: availableCount,
      inPantryCount: inPantryCount,
      stapleCount: stapleCount,
      userMarkedCount: userMarkedCount,
      missingCount: missingCount,
      matchPercentage: matchPercentage,
      hasManualMarks: hasManualMarks,
      expiringItemsUsed: List.unmodifiable(expiringUsed),
      summaryText: summary,
      missingSummaryText: missingSummary,
    );
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

  /// Word-boundary matching preventing substring collisions
  /// (e.g. "oil" must never match "boiled egg", "pea" must never match "peanut").
  static bool _isMatch(String pantryKeyword, String recipeIngredientKeyword) {
    if (pantryKeyword.isEmpty || recipeIngredientKeyword.isEmpty) return false;

    if (pantryKeyword == recipeIngredientKeyword) return true;

    // Word boundary match:
    final pPattern = RegExp(r'\b' + RegExp.escape(pantryKeyword) + r'\b');
    if (pPattern.hasMatch(recipeIngredientKeyword)) {
      return true;
    }

    final rPattern =
        RegExp(r'\b' + RegExp.escape(recipeIngredientKeyword) + r'\b');
    if (rPattern.hasMatch(pantryKeyword)) {
      return true;
    }

    return false;
  }

  static bool _isStapleUnavailable(
    String stapleRawName,
    String normalizedStaple,
    Set<String> unavailable,
  ) {
    if (unavailable.isEmpty) return false;
    if (unavailable.contains(normalizedStaple) ||
        unavailable.contains(stapleRawName.toLowerCase().trim())) {
      return true;
    }
    for (final u in unavailable) {
      if (u.isEmpty) continue;
      final pattern = RegExp(r'\b' + RegExp.escape(u) + r'\b');
      if (pattern.hasMatch(normalizedStaple) ||
          pattern.hasMatch(stapleRawName.toLowerCase())) {
        return true;
      }
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
