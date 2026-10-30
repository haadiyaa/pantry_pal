import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/recipes/data/datasources/recipe_remote_datasource.dart';
import 'package:pantry_pal/features/recipes/data/repositories/cached_recipe_repository.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_summary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockRecipeRemoteDataSource extends Mock implements RecipeRemoteDataSource {}

void main() {
  sqfliteFfiInit();

  late AppDatabase appDb;
  late MockRecipeRemoteDataSource remoteDataSource;
  late CachedRecipeRepository repository;

  final sampleRawRecipe = {
    'idMeal': '52772',
    'strMeal': 'Teriyaki Chicken Casserole',
    'strCategory': 'Chicken',
    'strArea': 'Japanese',
    'strInstructions': 'Bake chicken and rice.',
    'strMealThumb': 'https://example.com/teriyaki.jpg',
    'strYoutube': 'https://youtube.com/watch?v=123',
    'strIngredient1': 'chicken',
    'strMeasure1': '2 breasts',
  };

  setUp(() async {
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    remoteDataSource = MockRecipeRemoteDataSource();
    repository = CachedRecipeRepository(
      appDb: appDb,
      remoteDataSource: remoteDataSource,
    );
  });

  tearDown(() async {
    await appDb.close();
  });

  group('CachedRecipeRepository', () {
    final now = DateTime(2026, 10, 30, 12, 0);
    final pantry = [
      PantryItem(
        id: 1,
        name: 'Chicken Breast',
        quantity: 2,
        category: 'Meat and Fish',
        expiryDate: now.add(const Duration(days: 2)),
        addedAt: now,
      ),
    ];

    test('cache hit: returns cached recipes without invoking remote data source', () async {
      final db = await appDb.database;
      final oneHourAgo = now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;

      // Seed fresh ingredient search cache
      await db.insert(AppDatabase.tableIngredientSearchCache, {
        'keyword': 'chicken',
        'recipe_ids_json': jsonEncode(['52772']),
        'fetched_at': oneHourAgo,
      });

      // Seed fresh recipe detail cache
      await db.insert(AppDatabase.tableRecipeCache, {
        'id': '52772',
        'json': jsonEncode(sampleRawRecipe),
        'fetched_at': oneHourAgo,
      });

      final result = await repository.getRecipeSuggestions(pantryItems: pantry);

      expect(result.recipes.length, 1);
      expect(result.recipes.first.id, '52772');
      expect(result.recipes.first.name, 'Teriyaki Chicken Casserole');
      expect(result.isStale, isFalse);
      expect(result.isPartial, isFalse);

      verifyNever(() => remoteDataSource.filterByIngredient(any()));
      verifyNever(() => remoteDataSource.lookupRawById(any()));
    });

    test('cache miss then success: fetches from remote, writes to SQLite, returns recipes', () async {
      when(() => remoteDataSource.filterByIngredient('chicken')).thenAnswer(
        (_) async => [
          const RecipeSummary(id: '52772', name: 'Teriyaki Chicken Casserole'),
        ],
      );
      when(() => remoteDataSource.lookupRawById('52772')).thenAnswer(
        (_) async => sampleRawRecipe,
      );

      final result = await repository.getRecipeSuggestions(pantryItems: pantry);

      expect(result.recipes.length, 1);
      expect(result.recipes.first.name, 'Teriyaki Chicken Casserole');
      expect(result.isStale, isFalse);

      // Verify SQLite cache was populated
      final db = await appDb.database;
      final ingredientRows = await db.query(AppDatabase.tableIngredientSearchCache);
      expect(ingredientRows.length, 1);
      expect(ingredientRows.first['keyword'], 'chicken');

      final recipeRows = await db.query(AppDatabase.tableRecipeCache);
      expect(recipeRows.length, 1);
      expect(recipeRows.first['id'], '52772');
    });

    test('one ingredient request failing returns partial results with failed flag', () async {
      final multiPantry = [
        PantryItem(
          id: 1,
          name: 'Chicken Breast',
          quantity: 2,
          category: 'Meat and Fish',
          expiryDate: now.add(const Duration(days: 1)),
          addedAt: now,
        ),
        PantryItem(
          id: 2,
          name: 'Broccoli',
          quantity: 1,
          category: 'Vegetables',
          expiryDate: now.add(const Duration(days: 2)),
          addedAt: now,
        ),
      ];

      when(() => remoteDataSource.filterByIngredient('chicken')).thenAnswer(
        (_) async => [
          const RecipeSummary(id: '52772', name: 'Teriyaki Chicken Casserole'),
        ],
      );
      when(() => remoteDataSource.lookupRawById('52772')).thenAnswer(
        (_) async => sampleRawRecipe,
      );
      // Broccoli lookup times out
      when(() => remoteDataSource.filterByIngredient('broccoli')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/filter.php'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await repository.getRecipeSuggestions(pantryItems: multiPantry);

      expect(result.recipes.length, 1);
      expect(result.recipes.first.id, '52772');
      expect(result.isPartial, isTrue);
      expect(result.failedIngredients, contains('broccoli'));
    });

    test('all requests failing with stale cache returns stale results and sets isStale flag', () async {
      final db = await appDb.database;
      final twoDaysAgo = now.subtract(const Duration(days: 2)).millisecondsSinceEpoch;
      final tenDaysAgo = now.subtract(const Duration(days: 10)).millisecondsSinceEpoch;

      // Seed stale caches
      await db.insert(AppDatabase.tableIngredientSearchCache, {
        'keyword': 'chicken',
        'recipe_ids_json': jsonEncode(['52772']),
        'fetched_at': twoDaysAgo, // > 24 hours
      });
      await db.insert(AppDatabase.tableRecipeCache, {
        'id': '52772',
        'json': jsonEncode(sampleRawRecipe),
        'fetched_at': tenDaysAgo, // > 7 days
      });

      // Network throws 500 server error
      when(() => remoteDataSource.filterByIngredient(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/filter.php'),
          response: Response(
            requestOptions: RequestOptions(path: '/filter.php'),
            statusCode: 500,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final result = await repository.getRecipeSuggestions(pantryItems: pantry);

      expect(result.recipes.length, 1);
      expect(result.recipes.first.id, '52772');
      expect(result.isStale, isTrue);
    });

    test('all requests failing without cache throws exception', () async {
      when(() => remoteDataSource.filterByIngredient(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/filter.php'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => repository.getRecipeSuggestions(pantryItems: pantry),
        throwsA(isA<Exception>()),
      );
    });

    test('rate-limit or 429 response handled gracefully', () async {
      final db = await appDb.database;
      final staleTime = now.subtract(const Duration(days: 3)).millisecondsSinceEpoch;

      await db.insert(AppDatabase.tableIngredientSearchCache, {
        'keyword': 'chicken',
        'recipe_ids_json': jsonEncode(['52772']),
        'fetched_at': staleTime,
      });
      await db.insert(AppDatabase.tableRecipeCache, {
        'id': '52772',
        'json': jsonEncode(sampleRawRecipe),
        'fetched_at': staleTime,
      });

      // Simulate 429 Too Many Requests
      when(() => remoteDataSource.filterByIngredient('chicken')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/filter.php'),
          response: Response(
            requestOptions: RequestOptions(path: '/filter.php'),
            statusCode: 429,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      final result = await repository.getRecipeSuggestions(pantryItems: pantry);
      expect(result.recipes.length, 1);
      expect(result.isStale, isTrue);
    });

    test('cleanOldCache removes entries older than 30 days while preserving newer entries', () async {
      final db = await appDb.database;
      final fortyDaysAgo = DateTime.now().subtract(const Duration(days: 40)).millisecondsSinceEpoch;
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5)).millisecondsSinceEpoch;

      await db.insert(AppDatabase.tableRecipeCache, {
        'id': 'old_recipe',
        'json': '{}',
        'fetched_at': fortyDaysAgo,
      });
      await db.insert(AppDatabase.tableRecipeCache, {
        'id': 'fresh_recipe',
        'json': '{}',
        'fetched_at': fiveDaysAgo,
      });

      await repository.cleanOldCache();

      final remaining = await db.query(AppDatabase.tableRecipeCache);
      expect(remaining.length, 1);
      expect(remaining.first['id'], 'fresh_recipe');
    });
  });
}

