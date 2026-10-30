import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_item.dart';
import 'package:pantry_pal/features/shopping/domain/services/shopping_list_grouper.dart';

void main() {
  final now = DateTime(2026, 10, 30, 10, 0);

  group('ShoppingListGrouper', () {
    test('groups unchecked items by category and isolates bought items', () {
      final items = [
        ShoppingItem(
          id: 1,
          name: 'Milk',
          normalizedName: 'milk',
          quantity: 1,
          category: 'Dairy',
          isBought: false,
          addedAt: now,
        ),
        ShoppingItem(
          id: 2,
          name: 'Spinach',
          normalizedName: 'spinach',
          quantity: 1,
          category: 'Vegetables',
          isBought: false,
          addedAt: now.add(const Duration(minutes: 5)),
        ),
        ShoppingItem(
          id: 3,
          name: 'Cheese',
          normalizedName: 'cheese',
          quantity: 2,
          category: 'Dairy',
          isBought: false,
          addedAt: now.add(const Duration(minutes: 10)),
        ),
        ShoppingItem(
          id: 4,
          name: 'Bread',
          normalizedName: 'bread',
          quantity: 1,
          category: 'Grains',
          isBought: true,
          addedAt: now,
          boughtAt: now.add(const Duration(minutes: 15)),
        ),
      ];

      final grouped = ShoppingListGrouper.group(items);

      expect(grouped.uncheckedCount, 3);
      expect(grouped.boughtCount, 1);
      expect(grouped.totalCount, 4);
      expect(grouped.isEmpty, isFalse);
      expect(grouped.isEverythingBought, isFalse);

      // Check category groups
      expect(grouped.uncheckedCategories.keys.toList(), ['Dairy', 'Vegetables']);
      expect(grouped.uncheckedCategories['Dairy']?.length, 2);
      expect(grouped.uncheckedCategories['Vegetables']?.length, 1);

      // Check bought list
      expect(grouped.boughtItems.length, 1);
      expect(grouped.boughtItems.first.name, 'Bread');
    });

    test('deterministic category order follows canonical list', () {
      final items = [
        ShoppingItem(
          name: 'Apples',
          normalizedName: 'apple',
          category: 'Fruits',
          addedAt: now,
        ),
        ShoppingItem(
          name: 'Milk',
          normalizedName: 'milk',
          category: 'Dairy',
          addedAt: now,
        ),
        ShoppingItem(
          name: 'Carrot',
          normalizedName: 'carrot',
          category: 'Vegetables',
          addedAt: now,
        ),
      ];

      final grouped = ShoppingListGrouper.group(items);

      // Order: Dairy -> Vegetables -> Fruits
      expect(
        grouped.uncheckedCategories.keys.toList(),
        ['Dairy', 'Vegetables', 'Fruits'],
      );
    });

    test('handles empty list and everything-bought state', () {
      final empty = ShoppingListGrouper.group(const []);
      expect(empty.isEmpty, isTrue);
      expect(empty.uncheckedCount, 0);
      expect(empty.boughtCount, 0);
      expect(empty.isEverythingBought, isFalse);

      final allBought = ShoppingListGrouper.group([
        ShoppingItem(
          name: 'Milk',
          normalizedName: 'milk',
          isBought: true,
          addedAt: now,
          boughtAt: now,
        ),
      ]);
      expect(allBought.isEmpty, isFalse);
      expect(allBought.uncheckedCount, 0);
      expect(allBought.boughtCount, 1);
      expect(allBought.isEverythingBought, isTrue);
    });
  });
}

