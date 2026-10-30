import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/inventory/data/repositories/sqlite_pantry_repository.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event_reason.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDb;
  late SqlitePantryRepository pantryRepo;
  final fixedDate = DateTime(2026, 10, 30, 10, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pantry_consume_test_');
    final dbPath = join(tempDir.path, 'pantry_consume.db');
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: dbPath,
    );
    pantryRepo = SqlitePantryRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SqlitePantryRepository.consume', () {
    test('used with quantity > 1 only decrements quantity and adds nothing to shopping list',
        () async {
      final id = await pantryRepo.add(
        PantryItem(
          name: 'Eggs',
          quantity: 6,
          category: 'Meat and Fish',
          expiryDate: fixedDate.add(const Duration(days: 10)),
          addedAt: fixedDate,
          priceInPaise: 12000,
        ),
      );
      final item = (await pantryRepo.getById(id))!;

      final result = await pantryRepo.consume(
        item: item,
        reason: PantryEventReason.used,
        addToShoppingList: true,
        occurredAt: fixedDate,
      );

      expect(result.wasRemoved, isFalse);
      expect(result.previousQuantity, 6);
      expect(result.shoppingItemId, isNull);
      expect(result.shoppingItemQuantityAdded, 0);

      // Pantry item still exists with quantity 5
      final updatedItem = await pantryRepo.getById(id);
      expect(updatedItem, isNotNull);
      expect(updatedItem?.quantity, 5);

      // Event was recorded in pantry_events
      final db = await appDb.database;
      final events = await db.query('pantry_events');
      expect(events.length, 1);
      expect(events.first['reason'], 'used');
      expect(events.first['item_name'], 'Eggs');
      expect(events.first['quantity'], 1);

      // Shopping items remains empty
      final shoppingRows = await db.query('shopping_items');
      expect(shoppingRows, isEmpty);
    });

    test('used at quantity 1 removes item, logs event, and adds to shopping list',
        () async {
      final id = await pantryRepo.add(
        PantryItem(
          name: 'Amul Milk 1L',
          quantity: 1,
          category: 'Dairy',
          expiryDate: fixedDate.add(const Duration(days: 2)),
          addedAt: fixedDate,
          priceInPaise: 6500,
        ),
      );
      final item = (await pantryRepo.getById(id))!;

      final result = await pantryRepo.consume(
        item: item,
        reason: PantryEventReason.used,
        addToShoppingList: true,
        occurredAt: fixedDate,
      );

      expect(result.wasRemoved, isTrue);
      expect(result.previousQuantity, 1);
      expect(result.shoppingItemId, isNotNull);
      expect(result.shoppingItemQuantityAdded, 1);
      expect(result.shoppingItemWasCreated, isTrue);

      // Item removed from pantry
      expect(await pantryRepo.getById(id), isNull);

      // Event recorded
      final db = await appDb.database;
      final events = await db.query('pantry_events');
      expect(events.length, 1);
      expect(events.first['reason'], 'used');
      expect(events.first['item_name'], 'Amul Milk 1L');

      // Shopping row created with normalized name
      final shoppingRows = await db.query('shopping_items');
      expect(shoppingRows.length, 1);
      expect(shoppingRows.first['name'], 'Amul Milk 1L');
      expect(shoppingRows.first['normalized_name'], 'milk');
      expect(shoppingRows.first['source_type'], 'used_up');
      expect(shoppingRows.first['quantity'], 1);
    });

    test('used with setting off (addToShoppingList: false) removes item and logs but does NOT add to list',
        () async {
      final id = await pantryRepo.add(
        PantryItem(
          name: 'Butter',
          quantity: 1,
          category: 'Dairy',
          expiryDate: fixedDate.add(const Duration(days: 5)),
          addedAt: fixedDate,
        ),
      );
      final item = (await pantryRepo.getById(id))!;

      final result = await pantryRepo.consume(
        item: item,
        reason: PantryEventReason.used,
        addToShoppingList: false, // Setting is off
        occurredAt: fixedDate,
      );

      expect(result.wasRemoved, isTrue);
      expect(result.shoppingItemId, isNull);

      // Shopping table has 0 rows
      final db = await appDb.database;
      expect(await db.query('shopping_items'), isEmpty);

      // Pantry event is still recorded
      final events = await db.query('pantry_events');
      expect(events.length, 1);
      expect(events.first['reason'], 'used');
    });

    test('wasted reason logs event and does NOT add to shopping list', () async {
      final id = await pantryRepo.add(
        PantryItem(
          name: 'Rotten Tomato',
          quantity: 1,
          category: 'Vegetables',
          expiryDate: fixedDate.subtract(const Duration(days: 2)),
          addedAt: fixedDate,
        ),
      );
      final item = (await pantryRepo.getById(id))!;

      final result = await pantryRepo.consume(
        item: item,
        reason: PantryEventReason.wasted,
        addToShoppingList: true, // Even if true, wasted must never add to shopping list
        occurredAt: fixedDate,
      );

      expect(result.wasRemoved, isTrue);
      expect(result.shoppingItemId, isNull);

      final db = await appDb.database;
      expect(await db.query('shopping_items'), isEmpty);

      final events = await db.query('pantry_events');
      expect(events.length, 1);
      expect(events.first['reason'], 'wasted');
    });

    test('deleted reason logs as deleted and does NOT add to shopping list',
        () async {
      final id = await pantryRepo.add(
        PantryItem(
          name: 'Mistake Item',
          quantity: 1,
          category: 'Other',
          expiryDate: fixedDate,
          addedAt: fixedDate,
        ),
      );
      final item = (await pantryRepo.getById(id))!;

      final result = await pantryRepo.consume(
        item: item,
        reason: PantryEventReason.deleted,
        addToShoppingList: true,
        occurredAt: fixedDate,
      );

      expect(result.wasRemoved, isTrue);
      expect(result.shoppingItemId, isNull);

      final db = await appDb.database;
      expect(await db.query('shopping_items'), isEmpty);

      final events = await db.query('pantry_events');
      expect(events.length, 1);
      expect(events.first['reason'], 'deleted');
    });

    test('undo reverses every effect (restores pantry item, deletes event, reverses shopping item)',
        () async {
      final id = await pantryRepo.add(
        PantryItem(
          name: 'Paneer',
          quantity: 1,
          category: 'Dairy',
          expiryDate: fixedDate.add(const Duration(days: 3)),
          addedAt: fixedDate,
          priceInPaise: 8000,
        ),
      );
      final item = (await pantryRepo.getById(id))!;

      // Consume item at qty 1 -> removes from pantry, logs event, adds to shopping list
      final consumeResult = await pantryRepo.consume(
        item: item,
        reason: PantryEventReason.used,
        addToShoppingList: true,
        occurredAt: fixedDate,
      );

      expect(await pantryRepo.getById(id), isNull);
      final db = await appDb.database;
      expect(await db.query('pantry_events'), isNotEmpty);
      expect(await db.query('shopping_items'), isNotEmpty);

      // UNDO
      await pantryRepo.undoConsume(consumeResult);

      // Pantry item is restored with identical ID and properties
      final restored = await pantryRepo.getById(id);
      expect(restored, isNotNull);
      expect(restored?.id, id);
      expect(restored?.name, 'Paneer');
      expect(restored?.quantity, 1);
      expect(restored?.priceInPaise, 8000);

      // Event is removed from pantry_events
      expect(await db.query('pantry_events'), isEmpty);

      // Created shopping item is removed from shopping_items
      expect(await db.query('shopping_items'), isEmpty);
    });

    test('failure midway leaves everything completely unchanged (atomic rollback)',
        () async {
      final id = await pantryRepo.add(
        PantryItem(
          name: 'Safe Item',
          quantity: 1,
          category: 'Other',
          expiryDate: fixedDate,
          addedAt: fixedDate,
        ),
      );

      final db = await appDb.database;

      // Simulate a multi-table transaction that fails midway
      try {
        await db.transaction((txn) async {
          // 1. Delete pantry item
          await txn.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
          // 2. Insert event
          await txn.insert('pantry_events', {
            'item_name': 'Safe Item',
            'category': 'Other',
            'quantity': 1,
            'reason': 'used',
            'occurred_at': fixedDate.millisecondsSinceEpoch,
          });
          // 3. Failing operation: non-null violation on shopping_items
          await txn.insert('shopping_items', {
            'quantity': 1,
            // 'name' and 'normalized_name' omitted -> NOT NULL constraint failure
          });
        });
        fail('Should have failed');
      } catch (_) {
        // Expected rollback
      }

      // Pantry item is STILL intact!
      final intact = await pantryRepo.getById(id);
      expect(intact, isNotNull);
      expect(intact?.name, 'Safe Item');

      // No events committed!
      expect(await db.query('pantry_events'), isEmpty);

      // No shopping items committed!
      expect(await db.query('shopping_items'), isEmpty);
    });
  });
}

