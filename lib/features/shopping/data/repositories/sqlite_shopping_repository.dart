import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../inventory/domain/models/pantry_item.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';

class SqliteShoppingRepository implements ShoppingRepository {
  SqliteShoppingRepository(this._appDb) {
    _initStream();
  }

  final AppDatabase _appDb;
  static const _table = AppDatabase.tableShoppingItems;

  final StreamController<List<ShoppingItem>> _changeController =
      StreamController<List<ShoppingItem>>.broadcast();

  void _initStream() {
    getAll().then((items) {
      if (!_changeController.isClosed) {
        _changeController.add(items);
      }
    }).catchError((_) {});
  }

  Future<void> _notifyChange() async {
    if (_changeController.isClosed) return;
    try {
      final items = await getAll();
      if (!_changeController.isClosed) {
        _changeController.add(items);
      }
    } catch (_) {}
  }

  @override
  Future<List<ShoppingItem>> getAll() async {
    final db = await _appDb.database;
    final rows = await db.query(
      _table,
      orderBy: 'is_bought ASC, category ASC, added_at ASC',
    );
    return rows.map(ShoppingItem.fromMap).toList();
  }

  @override
  Stream<List<ShoppingItem>> watchAll() {
    _notifyChange();
    return _changeController.stream;
  }

  @override
  Future<ShoppingItem?> getById(int id) async {
    final db = await _appDb.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ShoppingItem.fromMap(rows.first);
  }

  @override
  Future<int> add(ShoppingItem item) async {
    final db = await _appDb.database;

    final id = await db.transaction((txn) async {
      return _addOrMergeInTxn(txn, item);
    });

    await _notifyChange();
    return id;
  }

  @override
  Future<void> addAll(List<ShoppingItem> items) async {
    if (items.isEmpty) return;
    final db = await _appDb.database;

    await db.transaction((txn) async {
      for (final item in items) {
        await _addOrMergeInTxn(txn, item);
      }
    });

    await _notifyChange();
  }

  Future<int> _addOrMergeInTxn(
    DatabaseExecutor txn,
    ShoppingItem item,
  ) async {
    // Duplicate merge rule: items are compared by their normalized name.
    // Merge only applies to unchecked items (is_bought = 0).
    final existing = await txn.query(
      _table,
      where: 'normalized_name = ? AND is_bought = 0',
      whereArgs: [item.normalizedName],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final row = existing.first;
      final existingId = row['id'] as int;
      final existingQty = (row['quantity'] as int?) ?? 1;
      final existingLabel = (row['source_label'] as String?) ?? '';

      final newQty = existingQty + item.quantity;
      final newLabel = _mergeLabels(existingLabel, item.sourceLabel);

      await txn.update(
        _table,
        {
          'quantity': newQty,
          'source_label': newLabel,
        },
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    } else {
      final map = item.toMap()..remove('id');
      return txn.insert(_table, map);
    }
  }

  String? _mergeLabels(String? current, String? incoming) {
    if (incoming == null || incoming.trim().isEmpty) return current;
    if (current == null || current.trim().isEmpty) return incoming.trim();
    final parts = current.split(', ').map((s) => s.trim()).toSet();
    parts.add(incoming.trim());
    return parts.join(', ');
  }

  @override
  Future<void> update(ShoppingItem item) async {
    if (item.id == null) {
      throw ArgumentError('Cannot update a shopping item without an id');
    }
    final db = await _appDb.database;
    await db.update(
      _table,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await _notifyChange();
  }

  @override
  Future<void> delete(int id) async {
    final db = await _appDb.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    await _notifyChange();
  }

  @override
  Future<void> restore(ShoppingItem item) async {
    final db = await _appDb.database;
    await db.insert(
      _table,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyChange();
  }

  @override
  Future<void> setBought(int id, bool isBought, {DateTime? boughtAt}) async {
    final db = await _appDb.database;
    final timestamp = isBought
        ? (boughtAt ?? DateTime.now()).millisecondsSinceEpoch
        : null;

    await db.update(
      _table,
      {
        'is_bought': isBought ? 1 : 0,
        'bought_at': timestamp,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _notifyChange();
  }

  @override
  Future<List<ShoppingItem>> clearBought() async {
    final db = await _appDb.database;

    final cleared = await db.transaction((txn) async {
      final rows = await txn.query(_table, where: 'is_bought = 1');
      final items = rows.map(ShoppingItem.fromMap).toList();
      await txn.delete(_table, where: 'is_bought = 1');
      return items;
    });

    await _notifyChange();
    return cleared;
  }

  @override
  Future<void> moveBoughtToPantry(
    List<PantryItem> pantryItems,
    List<int> shoppingItemIdsToRemove,
  ) async {
    final db = await _appDb.database;

    await db.transaction((txn) async {
      for (final item in pantryItems) {
        final map = item.toMap()..remove('id');
        await txn.insert(AppDatabase.tablePantryItems, map);
      }
      for (final id in shoppingItemIdsToRemove) {
        await txn.delete(_table, where: 'id = ?', whereArgs: [id]);
      }
    });

    await _notifyChange();
  }

  void dispose() {
    _changeController.close();
  }
}

