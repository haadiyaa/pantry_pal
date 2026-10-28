import '../../../inventory/domain/models/pantry_category.dart';

/// Maps Open Food Facts taxonomy tags or category strings into
/// one of Pantry Pal's 9 fixed categories, defaulting to 'Other'.
String mapOpenFoodFactsCategory(List<String> tags) {
  for (final rawTag in tags) {
    final tag = rawTag.toLowerCase().replaceAll('en:', '').trim();

    // 1. Frozen items (check before dairy to avoid ice-cream matching 'cream')
    if (tag.contains('frozen') ||
        tag.contains('ice-cream') ||
        tag.contains('ice cream')) {
      return PantryCategory.frozen.label;
    }

    // 2. Beverages (check before fruits to catch fruit-juices as beverages)
    if (tag.contains('beverage') ||
        tag.contains('drink') ||
        tag.contains('juice') ||
        tag.contains('soda') ||
        tag.contains('coffee') ||
        tag.contains('tea') ||
        tag.contains('water') ||
        tag.contains('beer') ||
        tag.contains('wine')) {
      return PantryCategory.beverages.label;
    }

    // 3. Dairy
    if (tag.contains('dairy') ||
        tag.contains('cheese') ||
        tag.contains('milk') ||
        tag.contains('yogurt') ||
        tag.contains('butter') ||
        tag.contains('cream') ||
        tag.contains('egg')) {
      return PantryCategory.dairy.label;
    }

    // 4. Vegetables
    if (tag.contains('vegetable') ||
        tag.contains('salad') ||
        tag.contains('onion') ||
        tag.contains('potato') ||
        tag.contains('tomato') ||
        tag.contains('cabbage') ||
        tag.contains('carrot') ||
        tag.contains('legume')) {
      return PantryCategory.vegetables.label;
    }

    // 5. Fruits
    if (tag.contains('fruit') ||
        tag.contains('apple') ||
        tag.contains('berry') ||
        tag.contains('berries') ||
        tag.contains('banana') ||
        tag.contains('citrus') ||
        tag.contains('orange')) {
      return PantryCategory.fruits.label;
    }

    // 6. Meat and Fish
    if (tag.contains('meat') ||
        tag.contains('beef') ||
        tag.contains('pork') ||
        tag.contains('poultry') ||
        tag.contains('chicken') ||
        tag.contains('turkey') ||
        tag.contains('fish') ||
        tag.contains('salmon') ||
        tag.contains('tuna') ||
        tag.contains('seafood')) {
      return PantryCategory.meatAndFish.label;
    }

    // 7. Grains
    if (tag.contains('grain') ||
        tag.contains('cereal') ||
        tag.contains('bread') ||
        tag.contains('pasta') ||
        tag.contains('flour') ||
        tag.contains('rice') ||
        tag.contains('oat') ||
        tag.contains('wheat') ||
        tag.contains('bakery')) {
      return PantryCategory.grains.label;
    }

    // 8. Snacks
    if (tag.contains('snack') ||
        tag.contains('biscuit') ||
        tag.contains('cookie') ||
        tag.contains('chocolate') ||
        tag.contains('crisp') ||
        tag.contains('chip') ||
        tag.contains('cracker') ||
        tag.contains('candy') ||
        tag.contains('sweet')) {
      return PantryCategory.snacks.label;
    }
  }

  return PantryCategory.other.label;
}
