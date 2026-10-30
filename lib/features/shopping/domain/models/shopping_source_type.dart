/// Represents how an item was added to the shopping list.
enum ShoppingSourceType {
  manual('manual', 'Manual'),
  usedUp('used_up', 'Used up'),
  recipe('recipe', 'Recipe');

  const ShoppingSourceType(this.storageKey, this.defaultLabel);

  final String storageKey;
  final String defaultLabel;

  static ShoppingSourceType fromStorageKey(String key) {
    return ShoppingSourceType.values.firstWhere(
      (type) => type.storageKey == key,
      orElse: () => ShoppingSourceType.manual,
    );
  }
}

