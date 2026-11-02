import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pantry_pal_migration_chain_');
    dbPath = join(tempDir.path, 'full_chain_migration.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Database successfully migrates through full chain v1 -> v2 -> v3 -> v4 -> v5 -> v6 preserving data', () async {
    final factory = databaseFactoryFfi;

    // 1. Create database at Version 1
    final v1Db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE pantry_items (
              id          INTEGER PRIMARY KEY AUTOINCREMENT,
              name        TEXT    NOT NULL,
              quantity    INTEGER NOT NULL DEFAULT 1,
              category    TEXT    NOT NULL DEFAULT 'Other',
              expiry_date INTEGER NOT NULL,
              barcode     TEXT,
              added_at    INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_pantry_items_expiry ON pantry_items (expiry_date)',
          );
        },
      ),
    );

    // Insert sample item in v1
    final insertedId = await v1Db.insert('pantry_items', {
      'name': 'Whole Milk',
      'quantity': 2,
      'category': 'Dairy',
      'expiry_date': 1700000000000,
      'barcode': '123456789',
      'added_at': 1690000000000,
    });
    expect(insertedId, 1);
    await v1Db.close();

    // 2. Open and upgrade to Version 6 using AppDatabase.onUpgrade
    final v6Db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppDatabase.dbVersion,
        onUpgrade: AppDatabase.onUpgrade,
      ),
    );

    // Verify v1 data is intact and new v2/v4 columns are null by default
    final rows = await v6Db.query('pantry_items', where: 'id = ?', whereArgs: [1]);
    expect(rows.length, 1);
    final row = rows.first;
    expect(row['name'], 'Whole Milk');
    expect(row['quantity'], 2);
    expect(row['category'], 'Dairy');
    expect(row['notes'], isNull); // Added in v2
    expect(row['price_paise'], isNull); // Added in v4

    // Verify updating notes and price_paise works on existing rows
    await v6Db.update(
      'pantry_items',
      {'notes': 'Organic grass-fed', 'price_paise': 6500},
      where: 'id = ?',
      whereArgs: [1],
    );
    final updated = await v6Db.query('pantry_items', where: 'id = ?', whereArgs: [1]);
    expect(updated.first['notes'], 'Organic grass-fed');
    expect(updated.first['price_paise'], 6500);

    // Verify Product cache table (v3) exists and accepts records
    await v6Db.insert('product_cache', {
      'barcode': '123456789',
      'name': 'Whole Milk',
      'brand': 'Local Dairy',
      'category': 'Dairy',
      'image_url': 'https://example.com/milk.png',
      'quantity': '1L',
      'fetched_at': 1690000001000,
    });
    final productRows = await v6Db.query('product_cache');
    expect(productRows.length, 1);

    // Verify Recipe cache and ingredient search cache tables (v5) exist
    await v6Db.insert('recipe_cache', {
      'id': 'recipe_1',
      'json': '{"title": "Pancake"}',
      'fetched_at': 1690000002000,
    });
    final recipeRows = await v6Db.query('recipe_cache');
    expect(recipeRows.length, 1);

    await v6Db.insert('ingredient_search_cache', {
      'keyword': 'milk',
      'recipe_ids_json': '["recipe_1"]',
      'fetched_at': 1690000003000,
    });
    final searchRows = await v6Db.query('ingredient_search_cache');
    expect(searchRows.length, 1);

    // Verify Shopping items and Pantry events tables (v6) exist
    await v6Db.insert('shopping_items', {
      'name': 'Flour',
      'normalized_name': 'flour',
      'quantity': 1,
      'category': 'Baking',
      'is_bought': 0,
      'source_type': 'manual',
      'source_label': 'Manual',
      'added_at': 1690000004000,
    });
    final shoppingRows = await v6Db.query('shopping_items');
    expect(shoppingRows.length, 1);

    await v6Db.insert('pantry_events', {
      'item_name': 'Whole Milk',
      'category': 'Dairy',
      'quantity': 1,
      'price_paise': 3250,
      'expiry_date': 1700000000000,
      'reason': 'used',
      'occurred_at': 1690000005000,
    });
    final eventRows = await v6Db.query('pantry_events');
    expect(eventRows.length, 1);

    await v6Db.close();
  });
}

