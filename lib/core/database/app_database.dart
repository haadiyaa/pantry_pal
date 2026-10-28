import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single access point for the SQLite database.
/// Bump [_dbVersion] and add a step in [_onUpgrade] for every schema change.
class AppDatabase {
  AppDatabase({DatabaseFactory? databaseFactory, String? dbPath})
      : _factory = databaseFactory,
        _customPath = dbPath;

  static final AppDatabase instance = AppDatabase();

  static const defaultDbName = 'pantry_pal.db';
  static const dbVersion = 1;

  static const tablePantryItems = 'pantry_items';

  final DatabaseFactory? _factory;
  final String? _customPath;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final String path;
    if (_customPath != null) {
      path = _customPath;
    } else if (_factory != null) {
      final dbPath = await _factory.getDatabasesPath();
      path = join(dbPath, defaultDbName);
    } else {
      path = join(await getDatabasesPath(), defaultDbName);
    }

    if (_factory != null) {
      return _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: dbVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: onCreate,
          onUpgrade: onUpgrade,
        ),
      );
    }

    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tablePantryItems (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        quantity     INTEGER NOT NULL DEFAULT 1,
        category     TEXT    NOT NULL DEFAULT 'Other',
        expiry_date  INTEGER NOT NULL, -- epoch milliseconds
        barcode      TEXT,
        added_at     INTEGER NOT NULL  -- epoch milliseconds
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pantry_items_expiry ON $tablePantryItems (expiry_date)',
    );
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migration logic for future schema versions
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
