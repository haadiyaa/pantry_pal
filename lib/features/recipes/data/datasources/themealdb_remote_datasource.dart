import 'package:dio/dio.dart';

import '../../domain/constants/recipe_matcher_constants.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_summary.dart';
import '../mappers/themealdb_recipe_mapper.dart';
import 'recipe_remote_datasource.dart';

/// TheMealDB remote data source implementation using Dio.
///
/// Uses the free public test API key "1" documented on TheMealDB.
/// Note: Commercial or production applications should obtain a dedicated
/// supporter/production key from TheMealDB (Patreon/PayPal).
class TheMealDbRemoteDataSource implements RecipeRemoteDataSource {
  TheMealDbRemoteDataSource({
    Dio? dio,
    String? baseUrl,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? RecipeMatcherConstants.theMealDbBaseUrl,
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent': 'PantryPal/1.0 (Flutter; Educational Portfolio)',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  @override
  Future<List<RecipeSummary>> filterByIngredient(String ingredient) async {
    final sanitized = ingredient.trim().replaceAll(' ', '_');
    if (sanitized.isEmpty) return const [];

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/filter.php',
        queryParameters: {'i': sanitized},
      );

      final data = response.data;
      if (data == null) return const [];

      final rawMeals = data['meals'];
      if (rawMeals == null || rawMeals is! List) return const [];

      final summaries = <RecipeSummary>[];
      for (final meal in rawMeals) {
        if (meal is Map<String, dynamic>) {
          final summary = TheMealDbRecipeMapper.fromFilterJson(meal);
          if (summary != null) summaries.add(summary);
        }
      }
      return summaries;
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<Recipe?> lookupById(String id) async {
    final raw = await lookupRawById(id);
    if (raw == null) return null;
    return TheMealDbRecipeMapper.fromMealJson(raw);
  }

  @override
  Future<Map<String, dynamic>?> lookupRawById(String id) async {
    if (id.trim().isEmpty) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lookup.php',
        queryParameters: {'i': id.trim()},
      );

      final data = response.data;
      if (data == null) return null;

      final rawMeals = data['meals'];
      if (rawMeals == null || rawMeals is! List || rawMeals.isEmpty) {
        return null;
      }

      final first = rawMeals.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      return null;
    } catch (_) {
      rethrow;
    }
  }
}

