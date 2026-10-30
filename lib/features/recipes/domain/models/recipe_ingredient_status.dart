/// The availability status of a recipe ingredient relative to the user's kitchen.
enum RecipeIngredientStatus {
  /// Matched against a real item currently in the user's pantry.
  inPantry,

  /// A standard documented household staple (salt, pepper, oil, water, etc.)
  /// not stored in the pantry inventory.
  staple,

  /// Neither in the pantry nor a staple (or a staple marked as unavailable).
  missing,
}

