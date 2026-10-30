import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient_status.dart';
import 'package:pantry_pal/features/recipes/domain/services/recipe_matcher.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 30, 10, 0);

  group('RecipeMatcher', () {
    test('computes perfect match (100%) when all non-staple ingredients are present', () {
      final pantry = [
        PantryItem(
          id: 1,
          name: 'Paneer',
          quantity: 1,
          category: 'Dairy',
          expiryDate: DateTime(2026, 11, 10),
          addedAt: fixedNow,
        ),
        PantryItem(
          id: 2,
          name: 'Spinach',
          quantity: 1,
          category: 'Vegetables',
          expiryDate: DateTime(2026, 11, 10),
          addedAt: fixedNow,
        ),
      ];

      const recipe = Recipe(
        id: '101',
        name: 'Palak Paneer',
        category: 'Vegetarian',
        area: 'Indian',
        instructions: 'Cook spinach and paneer with salt and water.',
        ingredients: [
          RecipeIngredient(name: 'Paneer', measure: '200g'),
          RecipeIngredient(name: 'Spinach', measure: '1 bunch'),
          RecipeIngredient(name: 'Salt', measure: '1 tsp'),
          RecipeIngredient(name: 'Water', measure: '1/2 cup'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipe],
        now: fixedNow,
      );

      expect(matches.length, 1);
      final match = matches.first;
      expect(match.matchPercentage, 1.0);
      expect(match.matchedCount, 2); // paneer, spinach matched in pantry
      expect(match.stapleCount, 2); // salt, water are kitchen staples, NOT labelled in-pantry
      expect(match.missingCount, 0);
      expect(match.expiringItemsUsed, isEmpty);
    });

    test('computes partial match and correctly lists missing non-staple ingredients', () {
      final pantry = [
        PantryItem(
          id: 1,
          name: 'Tomato',
          quantity: 2,
          category: 'Vegetables',
          expiryDate: DateTime(2026, 11, 10),
          addedAt: fixedNow,
        ),
      ];

      const recipe = Recipe(
        id: '102',
        name: 'Tomato Cucumber Salad',
        category: 'Vegetarian',
        area: 'International',
        instructions: 'Toss sliced tomatoes and cucumbers with olive oil.',
        ingredients: [
          RecipeIngredient(name: 'Tomato', measure: '2'),
          RecipeIngredient(name: 'Cucumber', measure: '1'),
          RecipeIngredient(name: 'Olive Oil', measure: '1 tbsp'),
          RecipeIngredient(name: 'Salt', measure: 'to taste'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipe],
        now: fixedNow,
      );

      expect(matches.length, 1);
      final match = matches.first;
      // Non-staples: Tomato (present), Cucumber (missing) -> 1 of 2 = 50%
      expect(match.matchPercentage, 0.5);
      expect(match.missingCount, 1);
      expect(match.missingIngredients.first.name, 'Cucumber');
    });

    test('staples (salt, oil, pepper, water) do not count as missing', () {
      final pantry = [
        PantryItem(
          id: 1,
          name: 'Potato',
          quantity: 3,
          category: 'Vegetables',
          expiryDate: DateTime(2026, 11, 10),
          addedAt: fixedNow,
        ),
      ];

      const recipe = Recipe(
        id: '103',
        name: 'Simple Boiled Potatoes',
        category: 'Vegetarian',
        area: 'International',
        instructions: 'Boil potatoes in salted water.',
        ingredients: [
          RecipeIngredient(name: 'Potato', measure: '2'),
          RecipeIngredient(name: 'Water', measure: '2 cups'),
          RecipeIngredient(name: 'Salt', measure: '1 tsp'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipe],
        now: fixedNow,
      );

      final match = matches.first;
      expect(match.matchPercentage, 1.0);
      expect(match.missingCount, 0);
    });

    test('prioritizes recipes using urgently expiring items over higher match percentage', () {
      final pantry = [
        // Expiring tomorrow!
        PantryItem(
          id: 1,
          name: 'Mushrooms',
          quantity: 1,
          category: 'Vegetables',
          expiryDate: fixedNow.add(const Duration(days: 1)),
          addedAt: fixedNow,
        ),
        // Not expiring soon
        PantryItem(
          id: 2,
          name: 'Rice',
          quantity: 1,
          category: 'Grains',
          expiryDate: fixedNow.add(const Duration(days: 100)),
          addedAt: fixedNow,
        ),
      ];

      // Recipe A: 100% match on rice, but uses NO expiring items
      const recipeA = Recipe(
        id: 'A',
        name: 'Plain Rice',
        category: 'Vegetarian',
        area: 'Asian',
        instructions: 'Boil rice in water.',
        ingredients: [
          RecipeIngredient(name: 'Rice', measure: '1 cup'),
          RecipeIngredient(name: 'Water', measure: '2 cups'),
        ],
      );

      // Recipe B: 50% match on mushrooms (missing cream), but consumes the urgently expiring mushrooms
      const recipeB = Recipe(
        id: 'B',
        name: 'Creamy Garlic Mushrooms',
        category: 'Vegetarian',
        area: 'European',
        instructions: 'Sauté mushrooms in cream and garlic.',
        ingredients: [
          RecipeIngredient(name: 'Mushrooms', measure: '200g'),
          RecipeIngredient(name: 'Heavy Cream', measure: '1/2 cup'),
          RecipeIngredient(name: 'Garlic', measure: '2 cloves'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipeA, recipeB],
        now: fixedNow,
      );

      expect(matches.length, 2);
      // Recipe B must rank FIRST despite lower match % because mushrooms are expiring tomorrow!
      expect(matches.first.recipe.id, 'B');
      expect(matches.first.expiringItemsUsed.length, 1);
      expect(matches.first.expiringItemsUsed.first.name, 'Mushrooms');
      expect(matches.last.recipe.id, 'A');
    });

    test('deterministic tie-breaker sorts by recipe name on identical scores', () {
      final pantry = [
        PantryItem(
          id: 1,
          name: 'Egg',
          quantity: 4,
          category: 'Dairy',
          expiryDate: fixedNow.add(const Duration(days: 10)),
          addedAt: fixedNow,
        ),
      ];

      const recipeZ = Recipe(
        id: '1',
        name: 'Zesty Scrambled Eggs',
        category: 'Breakfast',
        area: 'American',
        instructions: 'Scramble eggs with butter.',
        ingredients: [
          RecipeIngredient(name: 'Egg', measure: '2'),
          RecipeIngredient(name: 'Butter', measure: '1 tbsp'),
        ],
      );

      const recipeA = Recipe(
        id: '2',
        name: 'Classic Boiled Eggs',
        category: 'Breakfast',
        area: 'British',
        instructions: 'Boil eggs.',
        ingredients: [
          RecipeIngredient(name: 'Egg', measure: '2'),
          RecipeIngredient(name: 'Water', measure: '2 cups'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipeZ, recipeA],
        now: fixedNow,
      );

      expect(matches[0].recipe.name, 'Classic Boiled Eggs');
      expect(matches[1].recipe.name, 'Zesty Scrambled Eggs');
    });

    test('isVegetarian correctly filters non-vegetarian categories and ingredients', () {
      const chickenRecipe = Recipe(
        id: '1',
        name: 'Chicken Curry',
        category: 'Chicken',
        area: 'Indian',
        instructions: 'Cook chicken.',
        ingredients: [
          RecipeIngredient(name: 'Chicken', measure: '500g'),
        ],
      );

      const vegRecipe = Recipe(
        id: '2',
        name: 'Aloo Gobi',
        category: 'Vegetarian',
        area: 'Indian',
        instructions: 'Cook potatoes and cauliflower.',
        ingredients: [
          RecipeIngredient(name: 'Potato', measure: '2'),
          RecipeIngredient(name: 'Cauliflower', measure: '1'),
        ],
      );

      const meatInDisguise = Recipe(
        id: '3',
        name: 'Caesar Salad',
        category: 'Side',
        area: 'American',
        instructions: 'Toss romaine with anchovies and parmesan.',
        ingredients: [
          RecipeIngredient(name: 'Romaine Lettuce', measure: '1 head'),
          RecipeIngredient(name: 'Anchovies', measure: '3 fillets'),
        ],
      );

      expect(RecipeMatcher.isVegetarian(chickenRecipe), isFalse);
      expect(RecipeMatcher.isVegetarian(vegRecipe), isTrue);
      expect(RecipeMatcher.isVegetarian(meatInDisguise), isFalse);
    });

    test('handles empty candidate list and empty ingredients gracefully', () {
      final matches = RecipeMatcher.matchAndRank(
        pantryItems: [],
        candidateRecipes: [],
        now: fixedNow,
      );
      expect(matches, isEmpty);

      const emptyRecipe = Recipe(
        id: '999',
        name: 'Empty Dish',
        category: 'Other',
        area: 'Unknown',
        instructions: '',
        ingredients: [],
      );

      final singleMatch = RecipeMatcher.matchAndRank(
        pantryItems: [],
        candidateRecipes: [emptyRecipe],
        now: fixedNow,
      );
      expect(singleMatch.length, 1);
      expect(singleMatch.first.matchPercentage, 1.0);
    });

    test('only-staples recipe with empty pantry has 0 in-pantry and shows Staples', () {
      const stapleOnlyRecipe = Recipe(
        id: '500',
        name: 'Salt Water Solution',
        category: 'Other',
        area: 'Unknown',
        instructions: 'Mix salt with water and oil.',
        ingredients: [
          RecipeIngredient(name: 'Salt', measure: '1 tsp'),
          RecipeIngredient(name: 'Water', measure: '1 cup'),
          RecipeIngredient(name: 'Cooking Oil', measure: '1 tbsp'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: const [],
        candidateRecipes: [stapleOnlyRecipe],
        now: fixedNow,
      );

      expect(matches.length, 1);
      final match = matches.first;
      expect(match.matchedCount, 0); // Empty pantry: 0 in pantry!
      expect(match.stapleCount, 3);
      expect(match.missingCount, 0);
      expect(match.matchPercentage, 1.0);

      // In evaluateDetail:
      final detail = RecipeMatcher.evaluateDetail(
        recipe: stapleOnlyRecipe,
        pantryItems: const [],
        now: fixedNow,
      );
      expect(detail.inPantryCount, 0);
      expect(detail.stapleCount, 3);
      expect(detail.availableCount, 3);
      expect(detail.summaryText, 'You have 3 of 3 ingredients');
      for (final item in detail.items) {
        expect(item.status, RecipeIngredientStatus.staple);
      }
    });

    test('word boundary matching prevents substring false positives (oil != boiled egg, pea != peanut)', () {
      final pantryWithOil = [
        PantryItem(
          id: 1,
          name: 'Cooking Oil',
          quantity: 1,
          category: 'Other',
          expiryDate: DateTime(2026, 12, 1),
          addedAt: fixedNow,
        ),
        PantryItem(
          id: 2,
          name: 'Green Peas',
          quantity: 1,
          category: 'Vegetables',
          expiryDate: DateTime(2026, 12, 1),
          addedAt: fixedNow,
        ),
      ];

      const eggAndPeanutRecipe = Recipe(
        id: '600',
        name: 'Boiled Egg Peanut Salad',
        category: 'Salad',
        area: 'International',
        instructions: 'Mix boiled eggs and peanuts.',
        ingredients: [
          RecipeIngredient(name: 'Boiled Egg', measure: '2'),
          RecipeIngredient(name: 'Peanut', measure: '50g'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: pantryWithOil,
        candidateRecipes: [eggAndPeanutRecipe],
        now: fixedNow,
      );

      expect(matches.length, 1);
      final match = matches.first;
      // "oil" must NOT match "boiled egg"
      // "peas" must NOT match "peanut"
      expect(match.matchedCount, 0);
      expect(match.missingCount, 2);
      expect(match.matchPercentage, 0.0);
    });

    test('curd in pantry matches recipe calling for yogurt', () {
      final pantry = [
        PantryItem(
          id: 1,
          name: 'Amul Curd 500g',
          quantity: 1,
          category: 'Dairy',
          expiryDate: DateTime(2026, 11, 5),
          addedAt: fixedNow,
        ),
      ];

      const recipe = Recipe(
        id: '700',
        name: 'Yogurt Dip',
        category: 'Side',
        area: 'Greek',
        instructions: 'Mix yogurt with garlic.',
        ingredients: [
          RecipeIngredient(name: 'Greek Yogurt', measure: '1 cup'),
        ],
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipe],
        now: fixedNow,
      );

      expect(matches.length, 1);
      expect(matches.first.matchedCount, 1);
      expect(matches.first.matchPercentage, 1.0);
    });

    test('globally unavailable staples count as missing and reduce match percentage', () {
      final pantry = [
        PantryItem(
          id: 1,
          name: 'Pasta',
          quantity: 1,
          category: 'Grains',
          expiryDate: DateTime(2026, 11, 10),
          addedAt: fixedNow,
        ),
      ];

      const recipe = Recipe(
        id: '800',
        name: 'Simple Pasta',
        category: 'Pasta',
        area: 'Italian',
        instructions: 'Boil pasta, add oil and salt.',
        ingredients: [
          RecipeIngredient(name: 'Pasta', measure: '200g'),
          RecipeIngredient(name: 'Cooking Oil', measure: '2 tbsp'),
          RecipeIngredient(name: 'Salt', measure: '1 tsp'),
        ],
      );

      // Without overrides: 1 non-staple (pasta) in pantry, 2 available staples = 100%
      final matchesNormal = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipe],
        now: fixedNow,
      );
      expect(matchesNormal.first.matchPercentage, 1.0);

      // User marked "oil" as unavailable:
      final matchesWithOverride = RecipeMatcher.matchAndRank(
        pantryItems: pantry,
        candidateRecipes: [recipe],
        now: fixedNow,
        unavailableStaples: {'oil'},
      );
      final match = matchesWithOverride.first;
      // Pasta is in pantry (1), Cooking Oil is now missing (1), Salt is staple (1)
      // Non-staples: Pasta (matched), Cooking Oil (missing) -> 1 of 2 = 50%
      expect(match.matchPercentage, 0.5);
      expect(match.missingIngredients.map((i) => i.name), contains('Cooking Oil'));
    });
  });
}

