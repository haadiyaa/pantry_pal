import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pantry_pal_v4_v5_');
    dbPath = join(tempDir.path, 'migration_v4_v5.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Database properly migrates from schema v4 to v5 without data loss', () async {
    final factory = databaseFactoryFfi;

    // 1. Create database at Version 4
    final v4Db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE pantry_items (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              name         TEXT    NOT NULL,
              quantity     INTEGER NOT NULL DEFAULT 1,
              category     TEXT    NOT NULL DEFAULT 'Other',
              expiry_date  INTEGER NOT NULL,
              barcode      TEXT,
              added_at     INTEGER NOT NULL,
              notes        TEXT,
              price_paise  INTEGER
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_pantry_items_expiry ON pantry_items (expiry_date)',
          );
          await db.execute(
            'CREATE INDEX idx_pantry_items_category ON pantry_items (category)',
          );
          await db.execute('''
            CREATE TABLE product_cache (
              barcode    TEXT    PRIMARY KEY,
              name       TEXT    NOT NULL,
              brand      TEXT,
              category   TEXT    NOT NULL,
              image_url  TEXT,
              quantity   TEXT,
              fetched_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );

    // 2. Insert sample v4 rows
    final itemId = await v4Db.insert('pantry_items', {
      'name': 'Paneer 200g',
      'quantity': 2,
      'category': 'Dairy',
      'expiry_date': DateTime(2026, 11, 10).millisecondsSinceEpoch,
      'added_at': DateTime(2026, 10, 30).millisecondsSinceEpoch,
      'notes': 'Buy fresh next week',
      'price_paise': 9500,
    });
    expect(itemId, greaterThan(0));

    await v4Db.insert('product_cache', {
      'barcode': '8901234567890',
      'name': 'Amul Butter',
      'category': 'Dairy',
      'fetched_at': DateTime.now().millisecondsSinceEpoch,
    });

    await v4Db.close();

    // 3. Open via AppDatabase at Version 5 (triggers onUpgrade v4 -> v5)
    final appDb = AppDatabase(
      databaseFactory: factory,
      dbPath: dbPath,
    );
    final upgradedDb = await appDb.database;

    expect(await upgradedDb.getVersion(), 5);

    // 4. Verify existing data preserved
    final pantryRows = await upgradedDb.query('pantry_items');
    expect(pantryRows.length, 1);
    expect(pantryRows.first['name'], 'Paneer 200g');
    expect(pantryRows.first['price_paise'], 9500);
    expect(pantryRows.first['category'], 'Dairy');

    final productRows = await upgradedDb.query('product_cache');
    expect(productRows.length, 1);
    expect(productRows.first['barcode'], '8901234567890');

    // 5. Verify new recipe_cache table and index exist
    await upgradedDb.insert(AppDatabase.tableRecipeCache, {
      'id': '52772',
      'json': '{"strMeal": "Teriyaki Chicken"}',
      'fetched_at': 1700000000,
    });
    final recipeRows = await upgradedDb.query(AppDatabase.tableRecipeCache);
    expect(recipeRows.length, 1);
    expect(recipeRows.first['id'], '52772');

    // 6. Verify new ingredient_search_cache table and index exist
    await upgradedDb.insert(AppDatabase.tableIngredientSearchCache, {
      'keyword': 'chicken',
      'recipe_ids_json': '["52772"]',
      'fetched_at': 1700000000,
    });
    final ingredientRows = await upgradedDb.query(AppDatabase.tableIngredientSearchCache);
    expect(ingredientRows.length, 1);
    expect(ingredientRows.first['keyword'], 'chicken');

    await appDb.close();
  });
}

