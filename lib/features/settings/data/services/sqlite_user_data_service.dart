import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../domain/services/user_data_service.dart';

class SqliteUserDataService implements UserDataService {
  const SqliteUserDataService(this._appDb);

  final AppDatabase _appDb;

  @override
  Future<String> exportDataAsJson() async {
    final db = await _appDb.database;

    final pantryRows = await db.query(AppDatabase.tablePantryItems);
    final shoppingRows = await db.query(AppDatabase.tableShoppingItems);
    final eventRows = await db.query(AppDatabase.tablePantryEvents);

    final payload = {
      'app': 'Pantry Pal',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'pantry_items': pantryRows,
      'shopping_items': shoppingRows,
      'pantry_events': eventRows,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  @override
  Future<void> clearAllData() async {
    final db = await _appDb.database;

    await db.transaction((txn) async {
      await txn.delete(AppDatabase.tablePantryItems);
      await txn.delete(AppDatabase.tableShoppingItems);
      await txn.delete(AppDatabase.tablePantryEvents);
      await txn.delete(AppDatabase.tableProductCache);
      await txn.delete(AppDatabase.tableRecipeCache);
      await txn.delete(AppDatabase.tableIngredientSearchCache);
    });
  }
}

