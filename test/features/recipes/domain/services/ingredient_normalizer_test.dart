import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/recipes/domain/services/ingredient_normalizer.dart';

void main() {
  group('IngredientNormalizer', () {
    test('removes brand names, units, and noise words', () {
      expect(IngredientNormalizer.normalize('Amul Butter 500g'), 'butter');
      expect(IngredientNormalizer.normalize('Tata Salt 1kg'), 'salt');
      expect(IngredientNormalizer.normalize('Britannia Cheese Slices'), 'cheese');
      expect(IngredientNormalizer.normalize('Fresh Organic Spinach 250g'), 'spinach');
      expect(IngredientNormalizer.normalize('1 Packet Frozen Peas'), 'peas');
    });

    test('singularizes common plurals', () {
      expect(IngredientNormalizer.normalize('Eggs'), 'egg');
      expect(IngredientNormalizer.normalize('Onions'), 'onion');
      expect(IngredientNormalizer.normalize('Potatoes'), 'potato');
      expect(IngredientNormalizer.normalize('Tomatoes'), 'tomato');
      expect(IngredientNormalizer.normalize('Strawberries'), 'strawberry');
      expect(IngredientNormalizer.normalize('Green Chillies'), 'green chillies');
    });

    test('correctly maps Indian culinary synonyms to canonical keywords', () {
      expect(IngredientNormalizer.normalize('Curd'), 'yogurt');
      expect(IngredientNormalizer.normalize('Dahi'), 'yogurt');
      expect(IngredientNormalizer.normalize('Capsicum'), 'bell pepper');
      expect(IngredientNormalizer.normalize('Brinjal'), 'eggplant');
      expect(IngredientNormalizer.normalize('Bhindi'), 'okra');
      expect(IngredientNormalizer.normalize('Lady Finger'), 'okra');
      expect(IngredientNormalizer.normalize('Coriander Leaves'), 'cilantro');
      expect(IngredientNormalizer.normalize('Maida'), 'plain flour');
      expect(IngredientNormalizer.normalize('Atta'), 'flour');
      expect(IngredientNormalizer.normalize('Jeera'), 'cumin');
      expect(IngredientNormalizer.normalize('Haldi'), 'turmeric');
      expect(IngredientNormalizer.normalize('Spring Onion'), 'green onions');
      expect(IngredientNormalizer.normalize('Aloo'), 'potato');
      expect(IngredientNormalizer.normalize('Pyaaz'), 'onion');
      expect(IngredientNormalizer.normalize('Methi'), 'fenugreek');
      expect(IngredientNormalizer.normalize('Pudina'), 'mint');
      expect(IngredientNormalizer.normalize('Chana'), 'chickpeas');
      expect(IngredientNormalizer.normalize('Rajma'), 'kidney beans');
    });

    test('never falls back to category to prevent false recipe matches', () {
      expect(
        IngredientNormalizer.normalize('Amul 500g', category: 'Dairy'),
        '',
      );
    });

    test('handles empty, blank, and garbage characters safely', () {
      expect(IngredientNormalizer.normalize(''), '');
      expect(IngredientNormalizer.normalize('   '), '');
      expect(IngredientNormalizer.normalize('!@#\$%^&*()'), '');
      expect(IngredientNormalizer.normalize('12345 6789'), '');
    });

    test('isStaple correctly identifies standard kitchen staples without false positives', () {
      expect(IngredientNormalizer.isStaple('Salt'), isTrue);
      expect(IngredientNormalizer.isStaple('Sea Salt'), isTrue);
      expect(IngredientNormalizer.isStaple('Olive Oil'), isTrue);
      expect(IngredientNormalizer.isStaple('Cooking Oil'), isTrue);
      expect(IngredientNormalizer.isStaple('Water'), isTrue);

      // Word boundary protections: "oil" must never match "boiled egg"
      expect(IngredientNormalizer.isStaple('Boiled Egg'), isFalse);
      expect(IngredientNormalizer.isStaple('Egg'), isFalse);
      expect(IngredientNormalizer.isStaple('Peanut'), isFalse);
      expect(IngredientNormalizer.isStaple('Watermelon'), isFalse);
    });

    test('guessCategory accurately infers pantry category', () {
      expect(IngredientNormalizer.guessCategory('Chicken Breast').label, 'Meat and Fish');
      expect(IngredientNormalizer.guessCategory('Amul Butter').label, 'Dairy');
      expect(IngredientNormalizer.guessCategory('Red Apple').label, 'Fruits');
      expect(IngredientNormalizer.guessCategory('Bell Pepper').label, 'Vegetables');
      expect(IngredientNormalizer.guessCategory('Basmati Rice').label, 'Grains');
      expect(IngredientNormalizer.guessCategory('Orange Juice').label, 'Beverages');
    });
  });
}

