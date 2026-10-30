import 'dart:collection';

import '../../../inventory/domain/models/pantry_category.dart';
import '../models/grouped_shopping_list.dart';
import '../models/shopping_item.dart';

/// Pure functional service that groups shopping items by category
/// and partitions unchecked items from bought items deterministically.
class ShoppingListGrouper {
  const ShoppingListGrouper._();

  static const List<String> _categoryOrder = [
    'Dairy',
    'Vegetables',
    'Fruits',
    'Meat and Fish',
    'Grains',
    'Snacks',
    'Beverages',
    'Frozen',
    'Other',
  ];

  /// Groups [items] into unchecked category groups and a sorted bought section.
  static GroupedShoppingList group(List<ShoppingItem> items) {
    if (items.isEmpty) {
      return const GroupedShoppingList.empty();
    }

    final uncheckedMap = <String, List<ShoppingItem>>{};
    final boughtList = <ShoppingItem>[];

    for (final item in items) {
      if (item.isBought) {
        boughtList.add(item);
      } else {
        final cat = item.category.trim().isEmpty ? 'Other' : item.category.trim();
        // Normalize category casing using PantryCategory if recognized
        final resolvedCat = PantryCategory.fromString(cat).label;
        (uncheckedMap[resolvedCat] ??= []).add(item);
      }
    }

    // Sort items inside each category by addedAt ascending, then name
    for (final entry in uncheckedMap.entries) {
      entry.value.sort((a, b) {
        final dateComp = a.addedAt.compareTo(b.addedAt);
        if (dateComp != 0) return dateComp;
        return a.name.compareTo(b.name);
      });
    }

    // Order categories according to _categoryOrder, followed by any remaining alphabetically
    final sortedCategories = SplayTreeMap<String, List<ShoppingItem>>((a, b) {
      final indexA = _categoryOrder.indexOf(a);
      final indexB = _categoryOrder.indexOf(b);

      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      } else if (indexA != -1) {
        return -1;
      } else if (indexB != -1) {
        return 1;
      }
      return a.compareTo(b);
    });

    sortedCategories.addAll(uncheckedMap);

    // Sort bought items by boughtAt descending, then addedAt descending, then name
    boughtList.sort((a, b) {
      if (a.boughtAt != null && b.boughtAt != null) {
        final comp = b.boughtAt!.compareTo(a.boughtAt!);
        if (comp != 0) return comp;
      } else if (a.boughtAt != null) {
        return -1;
      } else if (b.boughtAt != null) {
        return 1;
      }
      final dateComp = b.addedAt.compareTo(a.addedAt);
      if (dateComp != 0) return dateComp;
      return a.name.compareTo(b.name);
    });

    return GroupedShoppingList(
      uncheckedCategories: Map.unmodifiable(sortedCategories),
      boughtItems: List.unmodifiable(boughtList),
    );
  }
}

