import '../../../../core/database/app_database.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';

class SqlitePantryRepository implements PantryRepository {
  const SqlitePantryRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = AppDatabase.tablePantryItems;

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
  Future<int> add(PantryItem item) async {
    final db = await _appDb.database;
    final map = item.toMap()..remove('id');
    return db.insert(_table, map);
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
    final db = await _appDb.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}

