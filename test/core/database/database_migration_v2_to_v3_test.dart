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
    tempDir = await Directory.systemTemp.createTemp('pantry_pal_v2_v3_');
    dbPath = join(tempDir.path, 'migration_v2_v3.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Database properly migrates from schema v2 to v3 without data loss',
      () async {
    final factory = databaseFactoryFfi;

    // 1. Create database at Version 2
    final v2Db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
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
              notes        TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_pantry_items_expiry ON pantry_items (expiry_date)',
          );
          await db.execute(
            'CREATE INDEX idx_pantry_items_category ON pantry_items (category)',
          );
        },
      ),
    );

    // 2. Insert sample rows at v2 (including notes)
    final itemId = await v2Db.insert('pantry_items', {
      'name': 'Organic Almond Milk',
      'quantity': 2,
      'category': 'Dairy',
      'expiry_date': 1761500000000,
      'barcode': '737628064502',
      'added_at': 1761000000000,
      'notes': 'Unopened in pantry',
    });
    expect(itemId, 1);

    await v2Db.close();

    // 3. Reopen using AppDatabase at Version 3
    final appDb = AppDatabase(
      databaseFactory: factory,
      dbPath: dbPath,
    );
    final v3Db = await appDb.database;

    // 4. Verify existing rows survived intact
    final rows = await v3Db.query('pantry_items', where: 'id = ?', whereArgs: [itemId]);
    expect(rows.length, 1);
    expect(rows.first['name'], 'Organic Almond Milk');
    expect(rows.first['notes'], 'Unopened in pantry');

    // 5. Verify product_cache table exists and functions
    final now = DateTime.now().millisecondsSinceEpoch;
    await v3Db.insert(AppDatabase.tableProductCache, {
      'barcode': '737628064502',
      'name': 'Organic Almond Milk',
      'brand': 'Oatly',
      'category': 'Dairy',
      'image_url': 'https://example.com/milk.jpg',
      'quantity': '1 L',
      'fetched_at': now,
    });

    final cachedRows = await v3Db.query(
      AppDatabase.tableProductCache,
      where: 'barcode = ?',
      whereArgs: ['737628064502'],
    );
    expect(cachedRows.length, 1);
    expect(cachedRows.first['brand'], 'Oatly');

    await appDb.close();
  });
}
