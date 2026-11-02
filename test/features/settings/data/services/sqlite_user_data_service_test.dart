import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/settings/data/services/sqlite_user_data_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase appDb;
  late SqliteUserDataService service;

  setUp(() async {
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    service = SqliteUserDataService(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  group('SqliteUserDataService', () {
    test('exportDataAsJson produces valid JSON payload with tables', () async {
      final db = await appDb.database;

      await db.insert('pantry_items', {
        'name': 'Greek Yogurt',
        'quantity': 1,
        'category': 'Dairy',
        'expiry_date': 1700000000000,
        'added_at': 1690000000000,
      });

      await db.insert('shopping_items', {
        'name': 'Oats',
        'normalized_name': 'oats',
        'quantity': 2,
        'category': 'Grains',
        'is_bought': 0,
        'source_type': 'manual',
        'added_at': 1690000001000,
      });

      final jsonString = await service.exportDataAsJson();
      expect(jsonString, isNotEmpty);

      final Map<String, dynamic> decoded =
          json.decode(jsonString) as Map<String, dynamic>;
      expect(decoded['app'], 'Pantry Pal');
      expect(decoded['version'], '1.0.0');
      expect((decoded['pantry_items'] as List).length, 1);
      expect((decoded['shopping_items'] as List).length, 1);
      expect(decoded['pantry_events'], isEmpty);
    });

    test('clearAllData wipes all tables and caches', () async {
      final db = await appDb.database;

      await db.insert('pantry_items', {
        'name': 'Greek Yogurt',
        'quantity': 1,
        'category': 'Dairy',
        'expiry_date': 1700000000000,
        'added_at': 1690000000000,
      });

      await db.insert('shopping_items', {
        'name': 'Oats',
        'normalized_name': 'oats',
        'quantity': 2,
        'category': 'Grains',
        'is_bought': 0,
        'source_type': 'manual',
        'added_at': 1690000001000,
      });

      await service.clearAllData();

      expect(await db.query('pantry_items'), isEmpty);
      expect(await db.query('shopping_items'), isEmpty);
      expect(await db.query('pantry_events'), isEmpty);
      expect(await db.query('product_cache'), isEmpty);
      expect(await db.query('recipe_cache'), isEmpty);
      expect(await db.query('ingredient_search_cache'), isEmpty);
    });
  });
}

