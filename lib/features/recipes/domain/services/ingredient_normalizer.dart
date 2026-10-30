import '../../../inventory/domain/models/pantry_category.dart';
import '../constants/recipe_matcher_constants.dart';

/// Pure Dart normalizer that converts pantry item names or recipe ingredient names
/// into canonical, standardized search keywords.
class IngredientNormalizer {
  const IngredientNormalizer();

  /// Normalizes [rawName] into a canonical ingredient keyword.
  ///
  /// Examples:
  /// - "Amul Butter 500g" -> "butter"
  /// - "Fresh Organic Spinach" -> "spinach"
  /// - "Curd" / "Dahi" -> "yogurt"
  /// - "Capsicum" -> "bell pepper"
  /// - "Brinjal" -> "eggplant"
  /// - "Coriander leaves" -> "cilantro"
  /// - "Maida" -> "plain flour"
  /// - "Atta" -> "flour"
  /// - "Eggs" -> "egg"
  /// - "Tomatoes" -> "tomato"
  static String normalize(String rawName, {String? category}) {
    if (rawName.trim().isEmpty) return '';

    // 1. Lowercase and separate fused numbers and units (e.g. "500g" -> "500 g", "1kg" -> "1 kg")
    var text = rawName.toLowerCase();
    text = text.replaceAllMapped(RegExp(r'(\d+)([a-z]+)'), (m) => '${m[1]} ${m[2]}');
    text = text.replaceAllMapped(RegExp(r'([a-z]+)(\d+)'), (m) => '${m[1]} ${m[2]}');
    // Replace non-alphanumeric characters with spaces
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // 2. Remove numeric values and quantities (e.g. 500, 1, 2.5)
    text = text.replaceAll(RegExp(r'\b\d+(\.\d+)?\b'), ' ');

    // 3. Tokenize words and filter out brand names & noise words
    final rawTokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final filteredTokens = <String>[];

    for (final token in rawTokens) {
      if (RecipeMatcherConstants.brandNames.contains(token)) continue;
      if (RecipeMatcherConstants.noiseWords.contains(token)) continue;
      filteredTokens.add(token);
    }

    if (filteredTokens.isEmpty) {
      return '';
    }

    var cleaned = filteredTokens.join(' ').trim();

    // 4. Check whole phrase against Indian/Colloquial synonym map
    if (RecipeMatcherConstants.ingredientSynonyms.containsKey(cleaned)) {
      return RecipeMatcherConstants.ingredientSynonyms[cleaned]!;
    }

    // 5. Check individual tokens or singularize words
    final singularTokens = filteredTokens.map(_singularize).toList();
    final singularizedPhrase = singularTokens.join(' ').trim();

    if (RecipeMatcherConstants.ingredientSynonyms.containsKey(singularizedPhrase)) {
      return RecipeMatcherConstants.ingredientSynonyms[singularizedPhrase]!;
    }

    // Check if any multi-word synonym is contained in the phrase
    for (final entry in RecipeMatcherConstants.ingredientSynonyms.entries) {
      if (singularizedPhrase == entry.key ||
          singularizedPhrase.split(' ').contains(entry.key)) {
        return entry.value;
      }
    }

    // Fallback: If ending with a recognized ingredient (e.g. "cheddar cheese" -> "cheese")
    if (singularTokens.length > 1) {
      final lastToken = singularTokens.last;
      if (RecipeMatcherConstants.ingredientSynonyms.containsKey(lastToken)) {
        return RecipeMatcherConstants.ingredientSynonyms[lastToken]!;
      }
      return singularizedPhrase;
    }

    return singularizedPhrase;
  }

  /// Simplistic English plural reduction
  static String _singularize(String word) {
    if (word.length <= 3) return word;

    // Special cases
    if (word == 'peas') return 'peas';
    if (word == 'leaves') return 'leaf';
    if (word == 'potatoes') return 'potato';
    if (word == 'tomatoes') return 'tomato';
    if (word == 'chillies' || word == 'chilies') return 'chilli';
    if (word == 'berries') return 'berry';
    if (word == 'strawberries') return 'strawberry';

    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.endsWith('es') && !word.endsWith('ses') && !word.endsWith('ches')) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Checks if an ingredient is a standard kitchen staple (salt, oil, water, etc.)
  /// Uses word-boundary matching to prevent false positives (e.g. "oil" must not match "boiled egg").
  static bool isStaple(String ingredientName) {
    final normalized = normalize(ingredientName);
    if (normalized.isEmpty) return false;

    if (RecipeMatcherConstants.pantryStaples.contains(normalized)) {
      return true;
    }
    for (final staple in RecipeMatcherConstants.pantryStaples) {
      if (normalized == staple) return true;
      final pattern = RegExp(r'\b' + RegExp.escape(staple) + r'\b');
      if (pattern.hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  /// Guesses the pantry category from an ingredient name using word-boundary tokens.
  static PantryCategory guessCategory(String ingredientName) {
    final lower = ingredientName.toLowerCase().trim();
    final normalized = normalize(ingredientName);

    // 1. Meat and Fish
    for (final kw in RecipeMatcherConstants.meatKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
      if (pattern.hasMatch(lower) || pattern.hasMatch(normalized)) {
        return PantryCategory.meatAndFish;
      }
    }
    const meatKeywordsExtra = [
      'chicken',
      'mutton',
      'beef',
      'pork',
      'bacon',
      'lamb',
      'prawn',
      'shrimp',
      'fish',
      'salmon',
      'tuna',
      'egg',
      'eggs',
      'turkey',
      'duck',
      'ham',
      'sausage',
    ];
    for (final kw in meatKeywordsExtra) {
      final pattern = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
      if (pattern.hasMatch(lower) || pattern.hasMatch(normalized)) {
        return PantryCategory.meatAndFish;
      }
    }

    // 2. Dairy
    const dairyKeywords = [
      'milk',
      'butter',
      'cheese',
      'yogurt',
      'yoghurt',
      'dahi',
      'curd',
      'paneer',
      'cream',
      'ghee',
      'buttermilk',
      'mayonnaise',
      'cottage cheese',
    ];
    for (final kw in dairyKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
      if (pattern.hasMatch(lower) || pattern.hasMatch(normalized)) {
        return PantryCategory.dairy;
      }
    }

    // 3. Beverages
    const beverageKeywords = [
      'juice',
      'tea',
      'coffee',
      'wine',
      'beer',
      'soda',
      'cider',
      'syrup',
      'drink',
    ];
    for (final kw in beverageKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
      if (pattern.hasMatch(lower) || pattern.hasMatch(normalized)) {
        return PantryCategory.beverages;
      }
    }

    // 4. Fruits
    const fruitKeywords = [
      'apple',
      'banana',
      'orange',
      'lemon',
      'lime',
      'mango',
      'berry',
      'strawberry',
      'blueberry',
      'grape',
      'grapes',
      'pineapple',
      'avocado',
      'watermelon',
      'coconut',
      'papaya',
      'peach',
      'plum',
      'pear',
    ];
    for (final kw in fruitKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
      if (pattern.hasMatch(lower) || pattern.hasMatch(normalized)) {
        return PantryCategory.fruits;
      }
    }
    const vegKeywords = [
      'onion',
      'tomato',
      'potato',
      'carrot',
      'capsicum',
      'bell pepper',
      'pepper',
      'garlic',
      'ginger',
      'spinach',
      'broccoli',
      'cauliflower',
      'cabbage',
      'peas',
      'mushroom',
      'aubergine',
      'brinjal',
      'eggplant',
      'cucumber',
      'lettuce',
      'coriander',
      'cilantro',
      'mint',
      'chili',
      'chilli',
      'corn',
      'zucchini',
      'okra',
      'bhindi',
      'celery',
      'kale',
      'radish',
      'beetroot',
      'pumpkin',
      'squash',
      'scallion',
      'leek',
    ];
    for (final kw in vegKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
      if (pattern.hasMatch(lower) || pattern.hasMatch(normalized)) {
        return PantryCategory.vegetables;
      }
    }

    // 5. Grains
    const grainKeywords = [
      'rice',
      'flour',
      'atta',
      'maida',
      'wheat',
      'oats',
      'pasta',
      'noodle',
      'noodles',
      'bread',
      'spaghetti',
      'quinoa',
      'cereal',
      'lentil',
      'lentils',
      'dal',
      'dhal',
      'chickpea',
      'chickpeas',
      'beans',
      'macaroni',
      'couscous',
    ];
    for (final kw in grainKeywords) {
      final pattern = RegExp(r'\b' + RegExp.escape(kw) + r'\b');
      if (pattern.hasMatch(lower) || pattern.hasMatch(normalized)) {
        return PantryCategory.grains;
      }
    }

    return PantryCategory.other;
  }
}
