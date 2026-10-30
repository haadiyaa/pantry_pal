import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import 'detail_ingredient_item.dart';

/// Live evaluation summary for a recipe displayed on the detail screen.
class RecipeDetailMatchResult extends Equatable {
  const RecipeDetailMatchResult({
    required this.items,
    required this.totalIngredients,
    required this.availableCount,
    required this.inPantryCount,
    required this.stapleCount,
    required this.userMarkedCount,
    required this.missingCount,
    required this.matchPercentage,
    required this.hasManualMarks,
    required this.expiringItemsUsed,
    required this.summaryText,
    required this.missingSummaryText,
  });

  /// Grouped/sorted ingredients (InPantry -> Marked -> Staples -> Missing).
  final List<DetailIngredientItem> items;

  /// Total number of ingredient lines in this recipe.
  final int totalIngredients;

  /// Count of all ingredients the user currently has (pantry + staples + marks).
  final int availableCount;

  /// Count of ingredients matched to real pantry stock.
  final int inPantryCount;

  /// Count of available kitchen staples.
  final int stapleCount;

  /// Count of non-staple missing ingredients the user manually ticked.
  final int userMarkedCount;

  /// Count of ingredients still missing.
  final int missingCount;

  /// Match percentage (0.0 to 1.0) excluding assumed staples.
  final double matchPercentage;

  /// True if the user has ticked at least one per-recipe mark.
  final bool hasManualMarks;

  /// Pantry items expiring soon utilized by this recipe.
  final List<PantryItem> expiringItemsUsed;

  /// Live summary label, e.g. "You have 7 of 9 ingredients".
  final String summaryText;

  /// Description of missing ingredients or confirmation of full availability.
  final String missingSummaryText;

  @override
  List<Object?> get props => [
        items,
        totalIngredients,
        availableCount,
        inPantryCount,
        stapleCount,
        userMarkedCount,
        missingCount,
        matchPercentage,
        hasManualMarks,
        expiringItemsUsed,
        summaryText,
        missingSummaryText,
      ];
}

