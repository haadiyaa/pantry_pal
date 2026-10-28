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
    tempDir = await Directory.systemTemp.createTemp('pantry_pal_migration_');
    dbPath = join(tempDir.path, 'migration_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Database properly migrates from schema v1 to v2 without data loss',
      () async {
    final factory = databaseFactoryFfi;

    // 1. Create database at Version 1
    final v1Db = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE pantry_items (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              name         TEXT    NOT NULL,
              quantity     INTEGER NOT NULL DEFAULT 1,
              category     TEXT    NOT NULL DEFAULT 'Other',
              expiry_date  INTEGER NOT NULL,
              barcode      TEXT,
              added_at     INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_pantry_items_expiry ON pantry_items (expiry_date)',
          );
        },
      ),
    );

    // 2. Insert sample rows at v1
    final itemId1 = await v1Db.insert('pantry_items', {
      'name': 'Greek Yogurt',
      'quantity': 2,
      'category': 'Dairy',
      'expiry_date': 1761500000000,
      'barcode': '123456789',
      'added_at': 1761000000000,
    });
    final itemId2 = await v1Db.insert('pantry_items', {
      'name': 'Spinach',
      'quantity': 1,
      'category': 'Vegetables',
      'expiry_date': 1761600000000,
      'barcode': null,
      'added_at': 1761000000000,
    });

    expect(itemId1, 1);
    expect(itemId2, 2);

    // 3. Close the v1 database
    await v1Db.close();

    // 4. Reopen using the AppDatabase configuration at Version 2
    final appDb = AppDatabase(
      databaseFactory: factory,
      dbPath: dbPath,
    );
    final v2Db = await appDb.database;

    // 5. Verify existing rows are intact
    final rows = await v2Db.query('pantry_items', orderBy: 'id ASC');
    expect(rows.length, 2);
    expect(rows[0]['name'], 'Greek Yogurt');
    expect(rows[0]['notes'], isNull); // New column exists and defaults to null
    expect(rows[1]['name'], 'Spinach');
    expect(rows[1]['notes'], isNull);

    // 6. Verify the new notes column accepts text updates and inserts
    await v2Db.update(
      'pantry_items',
      {'notes': 'Opened yesterday, finish first'},
      where: 'id = ?',
      whereArgs: [itemId1],
    );
    final updatedRows = await v2Db.query(
      'pantry_items',
      where: 'id = ?',
      whereArgs: [itemId1],
    );
    expect(updatedRows.first['notes'], 'Opened yesterday, finish first');

    // 7. Verify the new category index was created in SQLite master table
    final indexRows = await v2Db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_pantry_items_category'",
    );
    expect(indexRows.length, 1);
    expect(indexRows.first['name'], 'idx_pantry_items_category');

    await appDb.close();
  });
}
