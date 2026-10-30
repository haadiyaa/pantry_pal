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
    tempDir = await Directory.systemTemp.createTemp('pantry_pal_v3_v4_');
    dbPath = join(tempDir.path, 'migration_v3_v4.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Database properly migrates from schema v3 to v4 without data loss',
      () async {
    final factory = databaseFactoryFfi;

    // 1. Create database at Version 3
    final v3Db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
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

    // 2. Insert sample row at v3
    final itemId = await v3Db.insert('pantry_items', {
      'name': 'Greek Yogurt',
      'quantity': 2,
      'category': 'Dairy',
      'expiry_date': 1761500000000,
      'barcode': '8904083303077',
      'added_at': 1761000000000,
      'notes': 'Plain yoghurt',
    });
    expect(itemId, 1);

    await v3Db.close();

    // 3. Reopen using AppDatabase at Version 4
    final appDb = AppDatabase(
      databaseFactory: factory,
      dbPath: dbPath,
    );
    final v4Db = await appDb.database;

    // 4. Verify existing rows survived intact
    final rows = await v4Db.query('pantry_items', where: 'id = ?', whereArgs: [itemId]);
    expect(rows.length, 1);
    expect(rows.first['name'], 'Greek Yogurt');
    expect(rows.first['notes'], 'Plain yoghurt');
    // Newly added price_paise column defaults to null on existing rows
    expect(rows.first['price_paise'], isNull);

    // 5. Verify we can insert and update rows with price_paise at v4
    final newId = await v4Db.insert('pantry_items', {
      'name': 'Whole Milk',
      'quantity': 1,
      'category': 'Dairy',
      'expiry_date': 1761600000000,
      'added_at': 1761100000000,
      'price_paise': 4550, // Rs. 45.50
    });
    expect(newId, 2);

    final newRows = await v4Db.query('pantry_items', where: 'id = ?', whereArgs: [newId]);
    expect(newRows.first['price_paise'], 4550);

    await appDb.close();
  });
}

