import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/recipes/data/mappers/themealdb_recipe_mapper.dart';

void main() {
  Map<String, dynamic> loadFixture(String filename) {
    final file = File('test/fixtures/recipes/$filename');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('TheMealDbRecipeMapper', () {
    test('maps complete recipe detail fixture (Teriyaki Chicken) correctly', () {
      final json = loadFixture('meal_detail_teriyaki_chicken.json');
      final meals = json['meals'] as List;
      final mealMap = meals.first as Map<String, dynamic>;

      final recipe = TheMealDbRecipeMapper.fromMealJson(mealMap);

      expect(recipe, isNotNull);
      expect(recipe!.id, '52772');
      expect(recipe.name, 'Teriyaki Chicken Casserole');
      expect(recipe.category, 'Chicken');
      expect(recipe.area, 'Japanese');
      expect(recipe.imageUrl, 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg');
      expect(recipe.youtubeUrl, 'https://www.youtube.com/watch?v=4aZr5hZXP_s');
      expect(recipe.instructions, contains('Preheat oven to 350° F'));

      // 8 non-empty ingredients; slots 9..20 were blank/null and should be excluded
      expect(recipe.ingredients.length, 8);
      expect(recipe.ingredients[0].name, 'soy sauce');
      expect(recipe.ingredients[0].measure, '3/4 cup');
      expect(recipe.ingredients[5].name, 'chicken breasts');
      expect(recipe.ingredients[5].measure, '2');
      expect(recipe.ingredients[7].name, 'stir-fry vegetables');
      expect(recipe.ingredients[7].measure, '1 (12 oz.)');
    });

    test('handles recipe fixture with blank and null ingredient slots and measures', () {
      final json = loadFixture('meal_detail_with_blank_slots.json');
      final meals = json['meals'] as List;
      final mealMap = meals.first as Map<String, dynamic>;

      final recipe = TheMealDbRecipeMapper.fromMealJson(mealMap);

      expect(recipe, isNotNull);
      expect(recipe!.id, '52855');
      expect(recipe.name, 'Banana Pancakes');
      expect(recipe.youtubeUrl, isNull); // empty string mapped to null

      // Only 4 valid ingredients (banana, eggs, butter, cinnamon).
      // Slot 5 was whitespace ("   "), 6 was empty, 7..20 were null.
      expect(recipe.ingredients.length, 4);
      expect(recipe.ingredients[0].name, 'banana');
      expect(recipe.ingredients[0].measure, '1 large');
      expect(recipe.ingredients[2].name, 'butter');
      expect(recipe.ingredients[2].measure, ''); // empty measure allowed
      expect(recipe.ingredients[3].name, 'cinnamon');
      expect(recipe.ingredients[3].measure, ''); // null measure defaulted to empty string
    });

    test('maps filter results fixture into RecipeSummary items', () {
      final json = loadFixture('meal_filter_chicken.json');
      final meals = json['meals'] as List;

      final summaries = meals
          .map((m) => TheMealDbRecipeMapper.fromFilterJson(m as Map<String, dynamic>))
          .whereType<dynamic>()
          .toList();

      expect(summaries.length, 3);
      expect(summaries[0].id, '52940');
      expect(summaries[0].name, 'Brown Stew Chicken');
      expect(summaries[1].id, '53161');
      expect(summaries[1].name, 'Chicken & chorizo rice pot');
      expect(summaries[2].id, '52795');
      expect(summaries[2].name, 'Chicken Handi');
    });

    test('returns null when JSON is empty or missing essential fields', () {
      expect(TheMealDbRecipeMapper.fromMealJson(null), isNull);
      expect(TheMealDbRecipeMapper.fromMealJson({}), isNull);
      expect(TheMealDbRecipeMapper.fromMealJson({'idMeal': '123'}), isNull); // missing name
      expect(TheMealDbRecipeMapper.fromFilterJson(null), isNull);
      expect(TheMealDbRecipeMapper.fromFilterJson({}), isNull);
    });
  });
}

