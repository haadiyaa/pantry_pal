import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/product_lookup/data/datasources/open_food_facts_api.dart';
import 'package:pantry_pal/features/product_lookup/data/repositories/cached_product_lookup_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockDio extends Mock implements Dio {}

void main() {
  sqfliteFfiInit();

  late AppDatabase appDb;
  late MockDio mockDio;
  late OpenFoodFactsApi api;
  late CachedProductLookupRepository repository;

  setUp(() async {
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    mockDio = MockDio();
    api = OpenFoodFactsApi(dio: mockDio);
    repository = CachedProductLookupRepository(appDb: appDb, api: api);
  });

  tearDown(() async {
    await appDb.close();
  });

  group('CachedProductLookupRepository', () {
    const testBarcode = '737628064502';

    test('cache hit: returns cached product without making network request',
        () async {
      final db = await appDb.database;

      // Seed local cache with an entry fetched 2 days ago (< 30 days)
      final twoDaysAgo =
          DateTime.now().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
      await db.insert(AppDatabase.tableProductCache, {
        'barcode': testBarcode,
        'name': 'Thai Peanut Sauce',
        'brand': 'San-J',
        'category': 'Snacks',
        'image_url': 'https://example.com/sauce.jpg',
        'quantity': '296 ml',
        'fetched_at': twoDaysAgo,
      });

      final result = await repository.lookupProduct(testBarcode);

      expect(result, isNotNull);
      expect(result!.barcode, testBarcode);
      expect(result.name, 'Thai Peanut Sauce');
      expect(result.brand, 'San-J');

      // Dio was never called
      verifyNever(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ));
    });

    test(
        'cache miss: calls network, writes fresh product to SQLite cache, returns product',
        () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/$testBarcode.json'),
          statusCode: 200,
          data: {
            'status': 1,
            'product': {
              'code': testBarcode,
              'product_name': 'Organic Oat Milk',
              'brands': 'Oatly',
              'categories_tags': ['en:beverages', 'en:plant-based-milks'],
              'image_url': 'https://example.com/oat.jpg',
              'quantity': '1 L',
            },
          },
        ),
      );

      final result = await repository.lookupProduct(testBarcode);

      expect(result, isNotNull);
      expect(result!.name, 'Organic Oat Milk');
      expect(result.brand, 'Oatly');
      expect(result.category, 'Beverages');

      // Verify written into SQLite cache
      final db = await appDb.database;
      final cached = await db.query(
        AppDatabase.tableProductCache,
        where: 'barcode = ?',
        whereArgs: [testBarcode],
      );
      expect(cached.length, 1);
      expect(cached.first['name'], 'Organic Oat Milk');
    });

    test(
        'network failure with stale cache: falls back to stale cache entry (> 30 days)',
        () async {
      final db = await appDb.database;

      // Seed local cache with an entry fetched 40 days ago (> 30 days)
      final fortyDaysAgo =
          DateTime.now().subtract(const Duration(days: 40)).millisecondsSinceEpoch;
      await db.insert(AppDatabase.tableProductCache, {
        'barcode': testBarcode,
        'name': 'Greek Yogurt Stale',
        'brand': 'Chobani',
        'category': 'Dairy',
        'image_url': null,
        'quantity': '150 g',
        'fetched_at': fortyDaysAgo,
      });

      // Network request fails with DioException (e.g. offline / timeout)
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/$testBarcode.json'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await repository.lookupProduct(testBarcode);

      expect(result, isNotNull);
      expect(result!.name, 'Greek Yogurt Stale');
      expect(result.brand, 'Chobani');
    });

    test('network failure without cache: throws ProductLookupException',
        () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/$testBarcode.json'),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => repository.lookupProduct(testBarcode),
        throwsA(isA<ProductLookupException>()),
      );
    });

    test('product not found: returns null when Open Food Facts returns status 0',
        () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/$testBarcode.json'),
          statusCode: 200,
          data: {
            'status': 0,
            'status_verbose': 'product not found',
          },
        ),
      );

      final result = await repository.lookupProduct(testBarcode);
      expect(result, isNull);
    });
  });
}
