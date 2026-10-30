import 'package:equatable/equatable.dart';

import 'shopping_item.dart';

/// Immutable container of categorized unchecked shopping items and bought items.
class GroupedShoppingList extends Equatable {
  const GroupedShoppingList({
    required this.uncheckedCategories,
    required this.boughtItems,
  });

  const GroupedShoppingList.empty()
      : uncheckedCategories = const {},
        boughtItems = const [];

  /// Map of category name to items that have not yet been bought.
  final Map<String, List<ShoppingItem>> uncheckedCategories;

  /// List of items marked as bought.
  final List<ShoppingItem> boughtItems;

  int get uncheckedCount =>
      uncheckedCategories.values.fold(0, (sum, list) => sum + list.length);

  int get boughtCount => boughtItems.length;

  int get totalCount => uncheckedCount + boughtCount;

  bool get isEmpty => totalCount == 0;

  bool get isEverythingBought => uncheckedCount == 0 && boughtCount > 0;

  @override
  List<Object?> get props => [uncheckedCategories, boughtItems];
}

