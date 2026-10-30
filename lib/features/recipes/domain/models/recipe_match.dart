import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import 'recipe.dart';
import 'recipe_ingredient.dart';

/// Represents a candidate recipe matched against the user's pantry contents,
/// ranked by match percentage and the urgency of expiring items utilized.
class RecipeMatch extends Equatable {
  const RecipeMatch({
    required this.recipe,
    required this.matchedIngredients,
    required this.missingIngredients,
    required this.matchPercentage,
    required this.expiringItemsUsed,
    required this.score,
  });

  final Recipe recipe;
  final List<RecipeIngredient> matchedIngredients;
  final List<RecipeIngredient> missingIngredients;

  /// Match percentage expressed from 0.0 to 1.0 (excluding pantry staples).
  final double matchPercentage;

  /// Pantry items expiring within 3 days that this recipe consumes.
  final List<PantryItem> expiringItemsUsed;

  /// Deterministic composite score used for ranking candidate recipes.
  final double score;

  /// Whether this recipe utilizes at least one item expiring soon.
  bool get usesExpiringItems => expiringItemsUsed.isNotEmpty;

  /// Total count of ingredients the user needs to acquire (excluding staples).
  int get missingCount => missingIngredients.length;

  /// Total non-staple ingredients the user has on hand.
  int get matchedCount => matchedIngredients.length;

  @override
  List<Object?> get props => [
        recipe,
        matchedIngredients,
        missingIngredients,
        matchPercentage,
        expiringItemsUsed,
        score,
      ];
}

