import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/inventory/data/repositories/sqlite_pantry_repository.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late AppDatabase appDb;
  late SqlitePantryRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pantry_pal_add_all_');
    dbPath = join(tempDir.path, 'add_all_test.db');
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: dbPath,
    );
    repository = SqlitePantryRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SqlitePantryRepository.addAll', () {
    test('inserts all items in a single atomic transaction', () async {
      final now = DateTime.now();
      final items = [
        PantryItem(
          name: 'Fresh Milk',
          quantity: 2,
          category: 'Dairy',
          expiryDate: now.add(const Duration(days: 7)),
          addedAt: now,
          priceInPaise: 6400,
        ),
        PantryItem(
          name: 'White Bread',
          quantity: 1,
          category: 'Grains',
          expiryDate: now.add(const Duration(days: 5)),
          addedAt: now,
          priceInPaise: 4500,
        ),
      ];

      await repository.addAll(items);

      final stored = await repository.getAll();
      expect(stored.length, 2);
      expect(stored[0].name, 'White Bread');
      expect(stored[0].priceInPaise, 4500);
      expect(stored[1].name, 'Fresh Milk');
      expect(stored[1].priceInPaise, 6400);
    });

    test('rolls back completely if one insert fails', () async {
      final now = DateTime.now();
      final db = await appDb.database;

      // Add a unique constraint to name column to deliberately trigger a conflict
      await db.execute(
        'CREATE UNIQUE INDEX idx_unique_name ON pantry_items (name)',
      );

      // Pre-insert an item
      await repository.add(
        PantryItem(
          name: 'Unique Item',
          quantity: 1,
          category: 'Other',
          expiryDate: now,
          addedAt: now,
        ),
      );

      expect(await repository.countAll(), 1);

      // Try batch insert where second item triggers duplicate name constraint
      final batch = [
        PantryItem(
          name: 'New Item 1',
          quantity: 1,
          category: 'Other',
          expiryDate: now,
          addedAt: now,
        ),
        PantryItem(
          name: 'Unique Item', // Conflict!
          quantity: 2,
          category: 'Other',
          expiryDate: now,
          addedAt: now,
        ),
      ];

      expect(
        () => repository.addAll(batch),
        throwsA(isA<DatabaseException>()),
      );

      // Verify rollback: 'New Item 1' must NOT have been persisted!
      expect(await repository.countAll(), 1);
      final stored = await repository.getAll();
      expect(stored.length, 1);
      expect(stored.first.name, 'Unique Item');
    });
  });
}

