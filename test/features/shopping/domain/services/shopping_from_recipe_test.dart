import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_source_type.dart';
import 'package:pantry_pal/features/shopping/domain/services/shopping_from_recipe.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 30, 10, 0);

  const testRecipe = Recipe(
    id: '123',
    name: 'Butter Chicken',
    category: 'Chicken',
    area: 'Indian',
    instructions: 'Cook chicken in spices.',
    ingredients: [
      RecipeIngredient(name: 'Chicken Breast', measure: '500g'),
      RecipeIngredient(name: 'Tomato Puree', measure: '1 cup'),
      RecipeIngredient(name: 'Heavy Cream', measure: '1/2 cup'),
      RecipeIngredient(name: 'Salt', measure: '1 tsp'),
      RecipeIngredient(name: 'Water', measure: '1/2 cup'),
      RecipeIngredient(name: 'Cooking Oil', measure: '1 tbsp'),
      // Duplicate ingredient row
      RecipeIngredient(name: 'Heavy Cream', measure: '2 tbsp'),
    ],
  );

  group('ShoppingFromRecipe', () {
    test('extracts only Missing items: excludes pantry matches and assumed staples',
        () {
      // User has Chicken Breast in pantry.
      // Salt, Water, and Cooking Oil are assumed staples.
      // Heavy Cream is missing.
      final pantry = [
        PantryItem(
          id: 1,
          name: 'Chicken Breast',
          quantity: 2,
          category: 'Meat and Fish',
          expiryDate: fixedNow.add(const Duration(days: 3)),
          addedAt: fixedNow,
        ),
      ];

      final shoppingItems = ShoppingFromRecipe.fromRecipe(
        recipe: testRecipe,
        pantryItems: pantry,
        now: fixedNow,
      );

      // Only Heavy Cream and Tomato Puree (non-staple missing)
      // Salt, Water, Cooking Oil are assumed staples -> EXCLUDED
      // Chicken Breast is in pantry -> EXCLUDED
      final names = shoppingItems.map((i) => i.name).toList();
      expect(names, contains('Tomato Puree'));
      expect(names, contains('Heavy Cream'));
      expect(names, isNot(contains('Chicken Breast')));
      expect(names, isNot(contains('Salt')));
      expect(names, isNot(contains('Water')));
      expect(names, isNot(contains('Cooking Oil')));

      for (final item in shoppingItems) {
        expect(item.sourceType, ShoppingSourceType.recipe);
        expect(item.sourceLabel, 'Butter Chicken');
      }
    });

    test('excludes ingredients ticked "I have this" by the user', () {
      final pantry = <PantryItem>[];

      // User marks Heavy Cream as "I have this"
      final shoppingItems = ShoppingFromRecipe.fromRecipe(
        recipe: testRecipe,
        pantryItems: pantry,
        userMarkedAvailable: {'heavy cream'},
        now: fixedNow,
      );

      final names = shoppingItems.map((i) => i.name).toList();
      expect(names, isNot(contains('Heavy Cream')));
      expect(names, contains('Chicken Breast'));
      expect(names, contains('Tomato Puree'));
    });

    test('includes staples that the user globally marked unavailable', () {
      final pantry = <PantryItem>[];

      // User marked "oil" and "salt" as unavailable
      final shoppingItems = ShoppingFromRecipe.fromRecipe(
        recipe: testRecipe,
        pantryItems: pantry,
        unavailableStaples: {'oil', 'salt'},
        now: fixedNow,
      );

      final names = shoppingItems.map((i) => i.name).toList();
      // Salt and Cooking Oil are now INCLUDED because user is out of them
      expect(names, contains('Salt'));
      expect(names, contains('Cooking Oil'));
      // Water is still an available staple -> EXCLUDED
      expect(names, isNot(contains('Water')));
    });

    test('merges duplicate ingredient rows within the same recipe', () {
      final pantry = <PantryItem>[];

      final shoppingItems = ShoppingFromRecipe.fromRecipe(
        recipe: testRecipe,
        pantryItems: pantry,
        now: fixedNow,
      );

      // Heavy Cream was listed twice in testRecipe
      final creamItems =
          shoppingItems.where((i) => i.normalizedName == 'heavy cream').toList();
      expect(creamItems.length, 1);
      // Merged quantity = 1 + 1 = 2
      expect(creamItems.first.quantity, 2);
    });
  });
}
