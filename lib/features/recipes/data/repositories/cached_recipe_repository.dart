import 'dart:convert';

import 'package:pantry_pal/core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';
import '../../../inventory/domain/models/pantry_item.dart';
import '../../domain/models/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/ingredient_normalizer.dart';
import '../datasources/recipe_remote_datasource.dart';
import '../mappers/themealdb_recipe_mapper.dart';

/// Concrete implementation of [RecipeRepository] backed by SQLite caching and
/// [RecipeRemoteDataSource].
class CachedRecipeRepository implements RecipeRepository {
  CachedRecipeRepository({
    required this.appDb,
    required this.remoteDataSource,
    this.ingredientCacheValidity = const Duration(hours: 24),
    this.recipeCacheValidity = const Duration(days: 7),
  });

  final AppDatabase appDb;
  final RecipeRemoteDataSource remoteDataSource;
  final Duration ingredientCacheValidity;
  final Duration recipeCacheValidity;

  @override
  Future<RecipeQueryResult> getRecipeSuggestions({
    required List<PantryItem> pantryItems,
    int ingredientQueryCap = 6,
    int maxCandidateRecipes = 15,
    bool forceRefresh = false,
  }) async {
    if (pantryItems.isEmpty) {
      return const RecipeQueryResult(recipes: []);
    }

    // 1. Sort pantry items prioritizing soonest-to-expire items
    final sortedItems = List<PantryItem>.from(pantryItems)
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    // 2. Extract distinct canonical keywords, capped at [ingredientQueryCap]
    final uniqueKeywords = <String>[];
    for (final item in sortedItems) {
      if (item.quantity <= 0) continue;
      final keyword = IngredientNormalizer.normalize(
        item.name,
        category: item.category,
      );
      if (keyword.isNotEmpty && !uniqueKeywords.contains(keyword)) {
        uniqueKeywords.add(keyword);
        if (uniqueKeywords.length >= ingredientQueryCap) break;
      }
    }

    if (uniqueKeywords.isEmpty) {
      return const RecipeQueryResult(recipes: []);
    }

    bool isAnyStale = false;
    bool isAnyPartial = false;
    final failedKeywords = <String>[];
    final recipeOccurrences = <String, int>{};
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final db = await appDb.database;

    // 3. Query candidate recipe IDs for each ingredient keyword
    for (final keyword in uniqueKeywords) {
      List<String>? candidateIds;

      // Check SQLite ingredient cache first
      final cachedRows = await db.query(
        AppDatabase.tableIngredientSearchCache,
        where: 'keyword = ?',
        whereArgs: [keyword],
      );

      final hasCached = cachedRows.isNotEmpty;
      final cachedFetchedAt = hasCached
          ? (cachedRows.first['fetched_at'] as int? ?? 0)
          : 0;
      final isCacheFresh = (nowMs - cachedFetchedAt) <
          ingredientCacheValidity.inMilliseconds;

      if (hasCached && isCacheFresh && !forceRefresh) {
        try {
          final jsonString = cachedRows.first['recipe_ids_json'] as String;
          candidateIds = List<String>.from(jsonDecode(jsonString) as List);
        } catch (_) {
          candidateIds = null;
        }
      }

      // If cache miss or expired, query remote data source
      if (candidateIds == null) {
        try {
          final summaries = await remoteDataSource.filterByIngredient(keyword);
          candidateIds = summaries.map((s) => s.id).toList();

          // Write fresh IDs to database cache
          await db.insert(
            AppDatabase.tableIngredientSearchCache,
            {
              'keyword': keyword,
              'recipe_ids_json': jsonEncode(candidateIds),
              'fetched_at': nowMs,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {
          // Network failure: fall back to stale cache if present
          if (hasCached) {
            try {
              final jsonString = cachedRows.first['recipe_ids_json'] as String;
              candidateIds = List<String>.from(jsonDecode(jsonString) as List);
              isAnyStale = true;
            } catch (_) {
              candidateIds = null;
            }
          }

          if (candidateIds == null) {
            isAnyPartial = true;
            failedKeywords.add(keyword);
            continue;
          }
        }
      }

      for (final id in candidateIds) {
        recipeOccurrences[id] = (recipeOccurrences[id] ?? 0) + 1;
      }
    }

    // If all requests failed and we have 0 candidate recipes
    if (recipeOccurrences.isEmpty && failedKeywords.length == uniqueKeywords.length) {
      throw Exception('Failed to fetch recipes: Network unavailable and no cache.');
    }

    // 4. Rank candidate recipe IDs by occurrence count (most ingredients matched first)
    final sortedRecipeIds = recipeOccurrences.keys.toList()
      ..sort((a, b) => recipeOccurrences[b]!.compareTo(recipeOccurrences[a]!));

    final topRecipeIds = sortedRecipeIds.take(maxCandidateRecipes).toList();

    // 5. Fetch full recipe details for top candidates
    final recipes = <Recipe>[];
    for (final id in topRecipeIds) {
      final detailResult = await getRecipeById(id, forceRefresh: forceRefresh);
      if (detailResult.recipe != null) {
        recipes.add(detailResult.recipe!);
        if (detailResult.isStale) isAnyStale = true;
      }
    }

    return RecipeQueryResult(
      recipes: recipes,
      isStale: isAnyStale,
      isPartial: isAnyPartial,
      failedIngredients: failedKeywords,
    );
  }

  @override
  Future<RecipeDetailResult> getRecipeById(
    String id, {
    bool forceRefresh = false,
  }) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) {
      return const RecipeDetailResult();
    }

    final db = await appDb.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Check local SQLite recipe cache
    final cachedRows = await db.query(
      AppDatabase.tableRecipeCache,
      where: 'id = ?',
      whereArgs: [trimmedId],
    );

    final hasCached = cachedRows.isNotEmpty;
    final cachedFetchedAt = hasCached
        ? (cachedRows.first['fetched_at'] as int? ?? 0)
        : 0;
    final isCacheFresh = (nowMs - cachedFetchedAt) <
        recipeCacheValidity.inMilliseconds;

    if (hasCached && isCacheFresh && !forceRefresh) {
      try {
        final jsonString = cachedRows.first['json'] as String;
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        final recipe = TheMealDbRecipeMapper.fromMealJson(map);
        if (recipe != null) {
          return RecipeDetailResult(recipe: recipe, isStale: false);
        }
      } catch (_) {
        // Corrupted cache entry; proceed to network
      }
    }

    // Fetch from remote data source
    try {
      final rawJson = await remoteDataSource.lookupRawById(trimmedId);
      if (rawJson != null) {
        // Save raw JSON to SQLite cache
        await db.insert(
          AppDatabase.tableRecipeCache,
          {
            'id': trimmedId,
            'json': jsonEncode(rawJson),
            'fetched_at': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        final recipe = TheMealDbRecipeMapper.fromMealJson(rawJson);
        return RecipeDetailResult(recipe: recipe, isStale: false);
      }
    } catch (_) {
      // Network failed: Serve stale cache if available
      if (hasCached) {
        try {
          final jsonString = cachedRows.first['json'] as String;
          final map = jsonDecode(jsonString) as Map<String, dynamic>;
          final recipe = TheMealDbRecipeMapper.fromMealJson(map);
          if (recipe != null) {
            return RecipeDetailResult(recipe: recipe, isStale: true);
          }
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }

    return const RecipeDetailResult();
  }

  @override
  Future<void> cleanOldCache() async {
    await appDb.cleanOldCache(const Duration(days: 30));
  }
}
