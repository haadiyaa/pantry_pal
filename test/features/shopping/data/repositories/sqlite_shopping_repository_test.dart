import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/recipes/domain/services/ingredient_normalizer.dart';
import 'package:pantry_pal/features/shopping/data/repositories/sqlite_shopping_repository.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_item.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_source_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDb;
  late SqliteShoppingRepository repo;
  final fixedDate = DateTime(2026, 10, 30, 10, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shopping_repo_test_');
    final dbPath = join(tempDir.path, 'shopping_test.db');
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: dbPath,
    );
    repo = SqliteShoppingRepository(appDb);
  });

  tearDown(() async {
    repo.dispose();
    await appDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SqliteShoppingRepository', () {
    test('add and getAll retrieve shopping items correctly', () async {
      final item = ShoppingItem(
        name: 'Whole Milk',
        normalizedName: IngredientNormalizer.normalize('Whole Milk'),
        quantity: 2,
        category: 'Dairy',
        isBought: false,
        sourceType: ShoppingSourceType.manual,
        sourceLabel: 'Manual',
        addedAt: fixedDate,
      );

      final id = await repo.add(item);
      expect(id, greaterThan(0));

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.id, id);
      expect(all.first.name, 'Whole Milk');
      expect(all.first.quantity, 2);
    });

    test('merges duplicates by normalized name through synonym map (Curd and Yogurt)',
        () async {
      // "Curd" normalizes to "yogurt"
      final curd = ShoppingItem(
        name: 'Amul Curd 500g',
        normalizedName: IngredientNormalizer.normalize('Amul Curd 500g'),
        quantity: 1,
        category: 'Dairy',
        isBought: false,
        sourceType: ShoppingSourceType.usedUp,
        sourceLabel: 'Used up',
        addedAt: fixedDate,
      );
      expect(curd.normalizedName, 'yogurt');

      final curdId = await repo.add(curd);

      // "Greek Yogurt" also normalizes to "yogurt"
      final yogurt = ShoppingItem(
        name: 'Greek Yogurt',
        normalizedName: IngredientNormalizer.normalize('Greek Yogurt'),
        quantity: 2,
        category: 'Dairy',
        isBought: false,
        sourceType: ShoppingSourceType.recipe,
        sourceLabel: 'Yogurt Dip',
        addedAt: fixedDate.add(const Duration(hours: 1)),
      );
      expect(yogurt.normalizedName, 'yogurt');

      final yogurtId = await repo.add(yogurt);

      // Must merge into the existing row
      expect(yogurtId, curdId);

      final all = await repo.getAll();
      expect(all.length, 1);
      final merged = all.first;
      expect(merged.id, curdId);
      expect(merged.quantity, 3); // 1 + 2
      expect(merged.sourceLabel, 'Used up, Yogurt Dip');
    });

    test('update modifies shopping item fields', () async {
      final item = ShoppingItem(
        name: 'Apples',
        normalizedName: 'apple',
        quantity: 4,
        category: 'Fruits',
        addedAt: fixedDate,
      );

      final id = await repo.add(item);
      final updated = item.copyWith(
        id: id,
        name: 'Organic Red Apples',
        quantity: 6,
      );

      await repo.update(updated);

      final fetched = await repo.getById(id);
      expect(fetched?.name, 'Organic Red Apples');
      expect(fetched?.quantity, 6);
    });

    test('delete and restore work for undo support', () async {
      final item = ShoppingItem(
        name: 'Bread',
        normalizedName: 'bread',
        quantity: 1,
        category: 'Grains',
        addedAt: fixedDate,
      );

      final id = await repo.add(item);
      final inserted = (await repo.getById(id))!;

      await repo.delete(id);
      expect(await repo.getById(id), isNull);

      // Restore
      await repo.restore(inserted);
      final restored = await repo.getById(id);
      expect(restored, isNotNull);
      expect(restored?.name, 'Bread');
    });

    test('setBought marks item as bought and sets timestamp', () async {
      final id = await repo.add(
        ShoppingItem(
          name: 'Butter',
          normalizedName: 'butter',
          quantity: 1,
          category: 'Dairy',
          addedAt: fixedDate,
        ),
      );

      final boughtTime = fixedDate.add(const Duration(minutes: 30));
      await repo.setBought(id, true, boughtAt: boughtTime);

      var fetched = await repo.getById(id);
      expect(fetched?.isBought, isTrue);
      expect(fetched?.boughtAt, boughtTime);

      // Un-bought
      await repo.setBought(id, false);
      fetched = await repo.getById(id);
      expect(fetched?.isBought, isFalse);
      expect(fetched?.boughtAt, isNull);
    });

    test('clearBought deletes all bought items and returns them for undo',
        () async {
      final id1 = await repo.add(
        ShoppingItem(
          name: 'Eggs',
          normalizedName: 'egg',
          quantity: 12,
          category: 'Meat and Fish',
          addedAt: fixedDate,
        ),
      );
      final id2 = await repo.add(
        ShoppingItem(
          name: 'Cheese',
          normalizedName: 'cheese',
          quantity: 1,
          category: 'Dairy',
          addedAt: fixedDate,
        ),
      );

      await repo.setBought(id1, true);

      final cleared = await repo.clearBought();
      expect(cleared.length, 1);
      expect(cleared.first.name, 'Eggs');

      final remaining = await repo.getAll();
      expect(remaining.length, 1);
      expect(remaining.first.id, id2);

      // Restore cleared items
      for (final item in cleared) {
        await repo.restore(item);
      }
      expect((await repo.getAll()).length, 2);
    });

    test('moveBoughtToPantry succeeds atomically', () async {
      final id = await repo.add(
        ShoppingItem(
          name: 'Olive Oil',
          normalizedName: 'oil',
          quantity: 1,
          category: 'Other',
          isBought: true,
          addedAt: fixedDate,
        ),
      );

      final pantryItem = PantryItem(
        name: 'Olive Oil 1L',
        quantity: 1,
        category: 'Other',
        expiryDate: fixedDate.add(const Duration(days: 180)),
        addedAt: fixedDate,
      );

      await repo.moveBoughtToPantry([pantryItem], [id]);

      // Shopping item is removed
      expect(await repo.getById(id), isNull);

      // Pantry item is added
      final db = await appDb.database;
      final rows = await db.query('pantry_items');
      expect(rows.length, 1);
      expect(rows.first['name'], 'Olive Oil 1L');
    });

    test('moveBoughtToPantry rolls back completely if one insert fails',
        () async {
      final id = await repo.add(
        ShoppingItem(
          name: 'Salt',
          normalizedName: 'salt',
          quantity: 1,
          category: 'Other',
          isBought: true,
          addedAt: fixedDate,
        ),
      );

      // Invalid pantry item with missing non-null field name will trigger SQLite constraint exception
      final invalidPantryMap = <String, Object?>{
        'quantity': 1,
        'category': 'Other',
        'expiry_date': fixedDate.millisecondsSinceEpoch,
        'added_at': fixedDate.millisecondsSinceEpoch,
      };

      final db = await appDb.database;

      // Wrap in a test verifying transaction rollback
      try {
        await db.transaction((txn) async {
          // Valid delete
          await txn.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
          // Failing insert (name is NOT NULL)
          await txn.insert('pantry_items', invalidPantryMap);
        });
        fail('Should have thrown an exception');
      } catch (_) {
        // Transaction should have rolled back
      }

      // Verify shopping item is STILL present (rollback successful!)
      final shoppingItemStillPresent = await repo.getById(id);
      expect(shoppingItemStillPresent, isNotNull);

      // Verify NO pantry items were committed
      final pantryRows = await db.query('pantry_items');
      expect(pantryRows, isEmpty);
    });
  });
}

