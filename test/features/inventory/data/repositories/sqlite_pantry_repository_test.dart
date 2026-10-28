import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/inventory/data/repositories/sqlite_pantry_repository.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for headless desktop/testing environment
  sqfliteFfiInit();

  late AppDatabase appDb;
  late SqlitePantryRepository repository;

  setUp(() async {
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: inMemoryDatabasePath,
    );
    repository = SqlitePantryRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  group('SqlitePantryRepository (in-memory SQLite)', () {
    final now = DateTime.now();

    test('getAll returns empty list when table is empty', () async {
      final items = await repository.getAll();
      expect(items, isEmpty);
    });

    test('add persists an item and returns auto-incremented id', () async {
      final item = PantryItem(
        name: 'Organic Milk',
        quantity: 2,
        category: 'Dairy',
        expiryDate: now.add(const Duration(days: 5)),
        barcode: '1122334455',
        addedAt: now,
      );

      final id = await repository.add(item);
      expect(id, isPositive);

      final allItems = await repository.getAll();
      expect(allItems.length, 1);
      expect(allItems.first.id, id);
      expect(allItems.first.name, 'Organic Milk');
      expect(allItems.first.barcode, '1122334455');
    });

    test('getAll returns items ordered by expiry_date ASC', () async {
      final laterItem = PantryItem(
        name: 'Canned Beans',
        quantity: 1,
        category: 'Pantry',
        expiryDate: now.add(const Duration(days: 30)),
        addedAt: now,
      );
      final soonerItem = PantryItem(
        name: 'Fresh Fish',
        quantity: 1,
        category: 'Meat and Fish',
        expiryDate: now.add(const Duration(days: 2)),
        addedAt: now,
      );

      await repository.add(laterItem);
      await repository.add(soonerItem);

      final all = await repository.getAll();
      expect(all.length, 2);
      expect(all.first.name, 'Fresh Fish');
      expect(all.last.name, 'Canned Beans');
    });

    test('getById returns matching item or null when not found', () async {
      final item = PantryItem(
        name: 'Greek Yogurt',
        quantity: 4,
        category: 'Dairy',
        expiryDate: now.add(const Duration(days: 7)),
        addedAt: now,
      );

      final id = await repository.add(item);
      final found = await repository.getById(id);

      expect(found, isNotNull);
      expect(found!.id, id);
      expect(found.name, 'Greek Yogurt');

      final notFound = await repository.getById(9999);
      expect(notFound, isNull);
    });

    test('update modifies existing database record', () async {
      final item = PantryItem(
        name: 'Eggs',
        quantity: 6,
        category: 'Dairy',
        expiryDate: now.add(const Duration(days: 10)),
        addedAt: now,
      );

      final id = await repository.add(item);
      final savedItem = (await repository.getById(id))!;

      final updated = savedItem.copyWith(quantity: 12, name: 'Free-range Eggs');
      await repository.update(updated);

      final reloaded = await repository.getById(id);
      expect(reloaded!.quantity, 12);
      expect(reloaded.name, 'Free-range Eggs');
    });

    test('delete removes item from database', () async {
      final item = PantryItem(
        name: 'Spinach',
        quantity: 1,
        category: 'Vegetables',
        expiryDate: now.add(const Duration(days: 3)),
        addedAt: now,
      );

      final id = await repository.add(item);
      expect((await repository.getAll()).length, 1);

      await repository.delete(id);
      expect((await repository.getAll()), isEmpty);
    });

    test('getExpiringWithin returns only items expiring on or before cutoff',
        () async {
      final expiringTomorrow = PantryItem(
        name: 'Berries',
        expiryDate: now.add(const Duration(days: 1)),
        addedAt: now,
      );
      final expiringInTwoDays = PantryItem(
        name: 'Bread',
        expiryDate: now.add(const Duration(days: 2)),
        addedAt: now,
      );
      final expiringInTenDays = PantryItem(
        name: 'Rice',
        expiryDate: now.add(const Duration(days: 10)),
        addedAt: now,
      );

      await repository.add(expiringTomorrow);
      await repository.add(expiringInTwoDays);
      await repository.add(expiringInTenDays);

      final expiringSoon = await repository.getExpiringWithin(2);

      expect(expiringSoon.length, 2);
      expect(expiringSoon.map((i) => i.name), containsAll(['Berries', 'Bread']));
      expect(expiringSoon.map((i) => i.name), isNot(contains('Rice')));
    });
  });
}
