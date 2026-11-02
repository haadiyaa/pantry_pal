/// Template for `lib/core/config/api_keys.dart`.
///
/// Copy this file to `lib/core/config/api_keys.dart` and fill in any production
/// API keys or environment overrides.
class ApiKeys {
  const ApiKeys._();

  static const String theMealDbApiKey = String.fromEnvironment(
    'THE_MEAL_DB_API_KEY',
    defaultValue: '1',
  );

  static const String theMealDbBaseUrl = String.fromEnvironment(
    'THE_MEAL_DB_BASE_URL',
    defaultValue: 'https://www.themealdb.com/api/json/v1/$theMealDbApiKey',
  );

  static const String openFoodFactsBaseUrl = String.fromEnvironment(
    'OPEN_FOOD_FACTS_BASE_URL',
    defaultValue: 'https://world.openfoodfacts.org/api/v2/product',
  );
}
