import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../recipes/domain/services/ingredient_normalizer.dart';
import '../../domain/models/consume_result.dart';
import '../../domain/models/pantry_event.dart';
import '../../domain/models/pantry_event_reason.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';

class SqlitePantryRepository implements PantryRepository {
  const SqlitePantryRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = AppDatabase.tablePantryItems;

  String _escapeSqlLike(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  @override
  Future<List<PantryItem>> getAll() async {
    final db = await _appDb.database;
    final rows = await db.query(_table, orderBy: 'expiry_date ASC');
    return rows.map(PantryItem.fromMap).toList();
  }

  @override
  Future<PantryItem?> getById(int id) async {
    final db = await _appDb.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PantryItem.fromMap(rows.first);
  }

  @override
  Future<PantryItem?> getByBarcode(String barcode) async {
    final db = await _appDb.database;
    final rows = await db.query(
      _table,
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PantryItem.fromMap(rows.first);
  }

  @override
  Future<List<PantryItem>> getExpiringWithin(int days) async {
    final db = await _appDb.database;
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day + days,
      23,
      59,
      59,
      999,
    );
    final rows = await db.query(
      _table,
      where: 'expiry_date <= ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
      orderBy: 'expiry_date ASC',
    );
    return rows.map(PantryItem.fromMap).toList();
  }

  @override
  Future<List<PantryItem>> search({
    String? query,
    Set<String>? categories,
    int? expiringWithinDays,
  }) async {
    final db = await _appDb.database;
    final conditions = <String>[];
    final whereArgs = <Object?>[];

    if (query != null && query.trim().isNotEmpty) {
      final escaped = _escapeSqlLike(query.trim());
      conditions.add("name LIKE ? ESCAPE '\\'");
      whereArgs.add('%$escaped%');
    }

    if (categories != null && categories.isNotEmpty) {
      final placeholders = List.filled(categories.length, '?').join(', ');
      conditions.add('category IN ($placeholders)');
      whereArgs.addAll(categories);
    }

    if (expiringWithinDays != null) {
      final now = DateTime.now();
      final cutoff = DateTime(
        now.year,
        now.month,
        now.day + expiringWithinDays,
        23,
        59,
        59,
        999,
      );
      conditions.add('expiry_date <= ?');
      whereArgs.add(cutoff.millisecondsSinceEpoch);
    }

    final whereClause =
        conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final rows = await db.query(
      _table,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'expiry_date ASC',
    );

    return rows.map(PantryItem.fromMap).toList();
  }

  @override
  Future<int> countAll() async {
    final db = await _appDb.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_table'),
    );
    return count ?? 0;
  }

  @override
  Future<int> add(PantryItem item) async {
    final db = await _appDb.database;
    final map = item.toMap()..remove('id');
    return db.insert(_table, map);
  }

  @override
  Future<void> addAll(List<PantryItem> items) async {
    if (items.isEmpty) return;
    final db = await _appDb.database;
    await db.transaction((txn) async {
      for (final item in items) {
        final map = item.toMap()..remove('id');
        await txn.insert(_table, map);
      }
    });
  }

  @override
  Future<void> update(PantryItem item) async {
    if (item.id == null) {
      throw ArgumentError('Cannot update an item without an id');
    }
    final db = await _appDb.database;
    await db.update(
      _table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    final item = await getById(id);
    if (item != null) {
      await consume(
        item: item,
        reason: PantryEventReason.deleted,
        addToShoppingList: false,
      );
    } else {
      final db = await _appDb.database;
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    }
  }

  @override
  Future<ConsumeResult> consume({
    required PantryItem item,
    required PantryEventReason reason,
    bool addToShoppingList = false,
    DateTime? occurredAt,
  }) async {
    if (item.id == null) {
      throw ArgumentError('Cannot consume an item without an id');
    }

    final db = await _appDb.database;
    final now = occurredAt ?? DateTime.now();

    return db.transaction((txn) async {
      final wasRemoved = item.quantity <= 1;
      if (wasRemoved) {
        await txn.delete(_table, where: 'id = ?', whereArgs: [item.id]);
      } else {
        await txn.update(
          _table,
          {'quantity': item.quantity - 1},
          where: 'id = ?',
          whereArgs: [item.id],
        );
      }

      // Log event to pantry_events
      final eventMap = <String, Object?>{
        'item_name': item.name,
        'category': item.category,
        'quantity': 1,
        'price_paise': item.priceInPaise,
        'expiry_date': item.expiryDate.millisecondsSinceEpoch,
        'reason': reason.storageKey,
        'occurred_at': now.millisecondsSinceEpoch,
      };
      final eventId = await txn.insert(AppDatabase.tablePantryEvents, eventMap);
      final event = PantryEvent.fromMap({...eventMap, 'id': eventId});

      int? shoppingItemId;
      int shoppingQuantityAdded = 0;
      bool shoppingItemCreated = false;

      // Only for reason used, when addToShoppingList is true, and quantity reached 0:
      if (reason == PantryEventReason.used && addToShoppingList && wasRemoved) {
        final normalized = IngredientNormalizer.normalize(item.name);
        final key = normalized.isNotEmpty
            ? normalized
            : item.name.toLowerCase().trim();

        final existing = await txn.query(
          AppDatabase.tableShoppingItems,
          where: 'normalized_name = ? AND is_bought = 0',
          whereArgs: [key],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          final row = existing.first;
          final id = row['id'] as int;
          final currentQty = (row['quantity'] as int?) ?? 1;
          final currentLabels = (row['source_label'] as String?) ?? '';
          final newLabels = currentLabels.contains('Used up')
              ? currentLabels
              : (currentLabels.isEmpty ? 'Used up' : '$currentLabels, Used up');

          await txn.update(
            AppDatabase.tableShoppingItems,
            {
              'quantity': currentQty + 1,
              'source_label': newLabels,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          shoppingItemId = id;
          shoppingQuantityAdded = 1;
          shoppingItemCreated = false;
        } else {
          final newId = await txn.insert(
            AppDatabase.tableShoppingItems,
            {
              'name': item.name,
              'normalized_name': key,
              'quantity': 1,
              'category': item.category,
              'is_bought': 0,
              'source_type': 'used_up',
              'source_label': 'Used up',
              'added_at': now.millisecondsSinceEpoch,
              'bought_at': null,
            },
          );
          shoppingItemId = newId;
          shoppingQuantityAdded = 1;
          shoppingItemCreated = true;
        }
      }

      return ConsumeResult(
        item: item,
        event: event,
        previousQuantity: item.quantity,
        wasRemoved: wasRemoved,
        shoppingItemId: shoppingItemId,
        shoppingItemQuantityAdded: shoppingQuantityAdded,
        shoppingItemWasCreated: shoppingItemCreated,
      );
    });
  }

  @override
  Future<void> undoConsume(ConsumeResult result) async {
    final db = await _appDb.database;

    await db.transaction((txn) async {
      // 1. Remove the event
      if (result.event.id != null) {
        await txn.delete(
          AppDatabase.tablePantryEvents,
          where: 'id = ?',
          whereArgs: [result.event.id],
        );
      }

      // 2. Restore the pantry item / quantity
      if (result.wasRemoved) {
        // Re-insert item preserving original ID
        await txn.insert(_table, result.item.toMap());
      } else {
        await txn.update(
          _table,
          {'quantity': result.previousQuantity},
          where: 'id = ?',
          whereArgs: [result.item.id],
        );
      }

      // 3. Reverse shopping list addition
      if (result.shoppingItemQuantityAdded > 0 &&
          result.shoppingItemId != null) {
        if (result.shoppingItemWasCreated) {
          await txn.delete(
            AppDatabase.tableShoppingItems,
            where: 'id = ?',
            whereArgs: [result.shoppingItemId],
          );
        } else {
          final existing = await txn.query(
            AppDatabase.tableShoppingItems,
            columns: ['quantity'],
            where: 'id = ?',
            whereArgs: [result.shoppingItemId],
          );
          if (existing.isNotEmpty) {
            final currentQty = (existing.first['quantity'] as int?) ?? 1;
            final newQty = currentQty - result.shoppingItemQuantityAdded;
            if (newQty <= 0) {
              await txn.delete(
                AppDatabase.tableShoppingItems,
                where: 'id = ?',
                whereArgs: [result.shoppingItemId],
              );
            } else {
              await txn.update(
                AppDatabase.tableShoppingItems,
                {'quantity': newQty},
                where: 'id = ?',
                whereArgs: [result.shoppingItemId],
              );
            }
          }
        }
      }
    });
  }
}
