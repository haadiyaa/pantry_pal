import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import 'recipe_ingredient.dart';
import 'recipe_ingredient_status.dart';

/// Represents a single recipe ingredient evaluated for the detail screen,
/// including pantry presence, staple classification, and user manual marks.
class DetailIngredientItem extends Equatable {
  const DetailIngredientItem({
    required this.ingredient,
    required this.status,
    this.isUserMarkedAvailable = false,
    this.isStapleAvailable = true,
    this.matchedPantryItem,
  });

  final RecipeIngredient ingredient;
  final RecipeIngredientStatus status;

  /// True if the user manually ticked "I have this" for a non-pantry ingredient.
  /// (Per-recipe temporary state held only in memory).
  final bool isUserMarkedAvailable;

  /// For staples: true if assumed available; false if the user unticked it
  /// (persisted globally across recipes).
  final bool isStapleAvailable;

  /// The pantry item that satisfied this ingredient, if any.
  final PantryItem? matchedPantryItem;

  /// Whether the ingredient is available to cook with (via pantry, staple, or user tick).
  bool get isAvailable {
    switch (status) {
      case RecipeIngredientStatus.inPantry:
        return true;
      case RecipeIngredientStatus.staple:
        return isStapleAvailable;
      case RecipeIngredientStatus.missing:
        return isUserMarkedAvailable;
    }
  }

  /// Whether this row is a non-staple missing item that the user manually ticked.
  bool get isUserMarked =>
      status == RecipeIngredientStatus.missing && isUserMarkedAvailable;

  /// Whether this row represents an assumed-available staple.
  bool get isAvailableStaple =>
      status == RecipeIngredientStatus.staple && isStapleAvailable;

  /// Whether this row is currently missing (not in pantry, not marked, or unavailable staple).
  bool get isMissing => !isAvailable;

  DetailIngredientItem copyWith({
    RecipeIngredient? ingredient,
    RecipeIngredientStatus? status,
    bool? isUserMarkedAvailable,
    bool? isStapleAvailable,
    PantryItem? matchedPantryItem,
  }) {
    return DetailIngredientItem(
      ingredient: ingredient ?? this.ingredient,
      status: status ?? this.status,
      isUserMarkedAvailable:
          isUserMarkedAvailable ?? this.isUserMarkedAvailable,
      isStapleAvailable: isStapleAvailable ?? this.isStapleAvailable,
      matchedPantryItem: matchedPantryItem ?? this.matchedPantryItem,
    );
  }

  @override
  List<Object?> get props => [
        ingredient,
        status,
        isUserMarkedAvailable,
        isStapleAvailable,
        matchedPantryItem,
      ];
}

