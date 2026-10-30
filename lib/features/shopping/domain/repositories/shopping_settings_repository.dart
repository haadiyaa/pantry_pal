/// Settings repository for shopping list automations.
abstract interface class ShoppingSettingsRepository {
  /// Whether pantry items marked as "Used up" should be automatically
  /// added to the shopping list when their quantity reaches 0. Default is true.
  Future<bool> getAddUsedUpToShoppingList();

  /// Updates the setting.
  Future<void> setAddUsedUpToShoppingList(bool enabled);
}

