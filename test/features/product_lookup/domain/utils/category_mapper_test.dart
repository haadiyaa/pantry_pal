import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/product_lookup/domain/utils/category_mapper.dart';

void main() {
  group('mapOpenFoodFactsCategory', () {
    test('maps dairy tags correctly', () {
      expect(mapOpenFoodFactsCategory(['en:cheeses', 'en:dairy']), 'Dairy');
      expect(mapOpenFoodFactsCategory(['en:cow-milks']), 'Dairy');
      expect(mapOpenFoodFactsCategory(['en:yogurts']), 'Dairy');
    });

    test('maps vegetables tags correctly', () {
      expect(mapOpenFoodFactsCategory(['en:tomatoes', 'en:vegetables']),
          'Vegetables');
      expect(mapOpenFoodFactsCategory(['en:salads']), 'Vegetables');
    });

    test('maps fruits tags correctly', () {
      expect(mapOpenFoodFactsCategory(['en:apples', 'en:fruits']), 'Fruits');
      expect(mapOpenFoodFactsCategory(['en:berries']), 'Fruits');
    });

    test('maps meat and fish tags correctly', () {
      expect(
          mapOpenFoodFactsCategory(['en:poultries', 'en:meats']), 'Meat and Fish');
      expect(mapOpenFoodFactsCategory(['en:fishes', 'en:salmon']), 'Meat and Fish');
      expect(mapOpenFoodFactsCategory(['en:seafood']), 'Meat and Fish');
    });

    test('maps grains tags correctly', () {
      expect(mapOpenFoodFactsCategory(['en:breads', 'en:grains']), 'Grains');
      expect(mapOpenFoodFactsCategory(['en:pastas']), 'Grains');
      expect(mapOpenFoodFactsCategory(['en:cereals']), 'Grains');
    });

    test('maps snacks tags correctly', () {
      expect(mapOpenFoodFactsCategory(['en:biscuits', 'en:snacks']), 'Snacks');
      expect(mapOpenFoodFactsCategory(['en:chocolates']), 'Snacks');
      expect(mapOpenFoodFactsCategory(['en:crisps']), 'Snacks');
    });

    test('maps beverages tags correctly', () {
      expect(mapOpenFoodFactsCategory(['en:fruit-juices', 'en:beverages']),
          'Beverages');
      expect(mapOpenFoodFactsCategory(['en:coffees']), 'Beverages');
      expect(mapOpenFoodFactsCategory(['en:teas']), 'Beverages');
    });

    test('maps frozen foods tags correctly', () {
      expect(mapOpenFoodFactsCategory(['en:frozen-foods']), 'Frozen');
      expect(mapOpenFoodFactsCategory(['en:ice-cream']), 'Frozen');
    });

    test('defaults to Other for unrecognized tags or empty list', () {
      expect(mapOpenFoodFactsCategory([]), 'Other');
      expect(mapOpenFoodFactsCategory(['en:non-food-item']), 'Other');
    });
  });
}

