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
    tempDir = await Directory.systemTemp.createTemp('pantry_pal_v5_v6_');
    dbPath = join(tempDir.path, 'migration_v5_v6.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Database properly migrates from schema v5 to v6 without data loss', () async {
    final factory = databaseFactoryFfi;

    // 1. Create database at Version 5
    final v5Db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
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
          await db.execute('''
            CREATE TABLE recipe_cache (
              id         TEXT    PRIMARY KEY,
              json       TEXT    NOT NULL,
              fetched_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_recipe_cache_fetched ON recipe_cache (fetched_at)',
          );
          await db.execute('''
            CREATE TABLE ingredient_search_cache (
              keyword         TEXT    PRIMARY KEY,
              recipe_ids_json TEXT    NOT NULL,
              fetched_at      INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_ingredient_cache_fetched ON ingredient_search_cache (fetched_at)',
          );
        },
      ),
    );

    // 2. Insert sample v5 rows
    final itemId = await v5Db.insert('pantry_items', {
      'name': 'Greek Yogurt',
      'quantity': 2,
      'category': 'Dairy',
      'expiry_date': DateTime(2026, 11, 10).millisecondsSinceEpoch,
      'added_at': DateTime(2026, 10, 30).millisecondsSinceEpoch,
      'notes': 'Keep refrigerated',
      'price_paise': 4500,
    });
    expect(itemId, greaterThan(0));

    await v5Db.insert('recipe_cache', {
      'id': '52772',
      'json': '{"idMeal":"52772","strMeal":"Teriyaki Chicken"}',
      'fetched_at': DateTime.now().millisecondsSinceEpoch,
    });

    await v5Db.close();

    // 3. Open via AppDatabase at Version 6 (triggers onUpgrade v5 -> v6)
    final appDb = AppDatabase(
      databaseFactory: factory,
      dbPath: dbPath,
    );
    final upgradedDb = await appDb.database;

    expect(await upgradedDb.getVersion(), 6);

    // 4. Verify existing data preserved
    final pantryRows = await upgradedDb.query('pantry_items');
    expect(pantryRows.length, 1);
    expect(pantryRows.first['name'], 'Greek Yogurt');
    expect(pantryRows.first['price_paise'], 4500);

    final recipeRows = await upgradedDb.query('recipe_cache');
    expect(recipeRows.length, 1);
    expect(recipeRows.first['id'], '52772');

    // 5. Verify new tables exist and can accept valid inserts
    final shoppingId = await upgradedDb.insert('shopping_items', {
      'name': 'Whole Milk',
      'normalized_name': 'milk',
      'quantity': 2,
      'category': 'Dairy',
      'is_bought': 0,
      'source_type': 'manual',
      'source_label': 'Manual',
      'added_at': DateTime.now().millisecondsSinceEpoch,
    });
    expect(shoppingId, greaterThan(0));

    final eventId = await upgradedDb.insert('pantry_events', {
      'item_name': 'Greek Yogurt',
      'category': 'Dairy',
      'quantity': 1,
      'price_paise': 4500,
      'expiry_date': DateTime(2026, 11, 10).millisecondsSinceEpoch,
      'reason': 'used',
      'occurred_at': DateTime.now().millisecondsSinceEpoch,
    });
    expect(eventId, greaterThan(0));

    // 6. Verify indexes exist on new tables
    final shoppingIndexes = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='shopping_items'",
    );
    final shoppingIndexNames =
        shoppingIndexes.map((row) => row['name'] as String).toList();
    expect(shoppingIndexNames, contains('idx_shopping_items_normalized_name'));
    expect(shoppingIndexNames, contains('idx_shopping_items_is_bought'));

    final eventIndexes = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='pantry_events'",
    );
    final eventIndexNames =
        eventIndexes.map((row) => row['name'] as String).toList();
    expect(eventIndexNames, contains('idx_pantry_events_occurred_at'));
    expect(eventIndexNames, contains('idx_pantry_events_reason'));

    await appDb.close();
  });

  test('Fresh install (onCreate) and upgrade (onUpgrade) produce identical schemas',
      () async {
    final factory = databaseFactoryFfi;

    final freshDbPath = join(tempDir.path, 'fresh_v6.db');
    final upgradedDbPath = join(tempDir.path, 'upgraded_v6.db');

    // 1. Create fresh DB via onCreate
    final freshAppDb = AppDatabase(
      databaseFactory: factory,
      dbPath: freshDbPath,
    );
    final freshDb = await freshAppDb.database;

    // 2. Create upgraded DB from v1 all the way to v6 via onUpgrade
    final oldDb = await factory.openDatabase(
      upgradedDbPath,
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
    await oldDb.close();

    final upgradedAppDb = AppDatabase(
      databaseFactory: factory,
      dbPath: upgradedDbPath,
    );
    final upgradedDb = await upgradedAppDb.database;

    // Compare all tables and columns between fresh and upgraded
    Future<Map<String, List<Map<String, Object?>>>> getTableInfo(
        Database db) async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final result = <String, List<Map<String, Object?>>>{};
      for (final row in tables) {
        final table = row['name'] as String;
        final columns = await db.rawQuery("PRAGMA table_info($table)");
        result[table] = columns;
      }
      return result;
    }

    final freshInfo = await getTableInfo(freshDb);
    final upgradedInfo = await getTableInfo(upgradedDb);

    expect(freshInfo.keys, equals(upgradedInfo.keys));
    for (final table in freshInfo.keys) {
      final freshCols = freshInfo[table]!;
      final upgradedCols = upgradedInfo[table]!;
      expect(
        freshCols.map((c) => c['name']).toSet(),
        equals(upgradedCols.map((c) => c['name']).toSet()),
        reason: 'Mismatch in column names for table $table',
      );
    }

    await freshAppDb.close();
    await upgradedAppDb.close();
  });
}
