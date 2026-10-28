import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single access point for the SQLite database.
/// Bump [dbVersion] and add a step in [onUpgrade] for every schema change.
class AppDatabase {
  AppDatabase({DatabaseFactory? databaseFactory, String? dbPath})
      : _factory = databaseFactory,
        _customPath = dbPath;

  static final AppDatabase instance = AppDatabase();

  static const defaultDbName = 'pantry_pal.db';
  static const dbVersion = 3;

  static const tablePantryItems = 'pantry_items';
  static const tableProductCache = 'product_cache';

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

  /// Fresh install creates the full, current (v3) schema directly.
  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tablePantryItems (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        quantity     INTEGER NOT NULL DEFAULT 1,
        category     TEXT    NOT NULL DEFAULT 'Other',
        expiry_date  INTEGER NOT NULL, -- epoch milliseconds
        barcode      TEXT,
        added_at     INTEGER NOT NULL, -- epoch milliseconds
        notes        TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pantry_items_expiry ON $tablePantryItems (expiry_date)',
    );
    await db.execute(
      'CREATE INDEX idx_pantry_items_category ON $tablePantryItems (category)',
    );

    // Schema v3: Product cache table for Open Food Facts lookups
    await db.execute('''
      CREATE TABLE $tableProductCache (
        barcode    TEXT    PRIMARY KEY,
        name       TEXT    NOT NULL,
        brand      TEXT,
        category   TEXT    NOT NULL,
        image_url  TEXT,
        quantity   TEXT,
        fetched_at INTEGER NOT NULL -- epoch milliseconds
      )
    ''');
  }

  /// Upgrades existing databases incrementally without data loss.
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // Version 2: Add notes column and category index
      await db.execute(
        'ALTER TABLE $tablePantryItems ADD COLUMN notes TEXT',
      );
      await db.execute(
        'CREATE INDEX idx_pantry_items_category ON $tablePantryItems (category)',
      );
    }
    if (oldVersion < 3) {
      // Version 3: Add product cache table
      await db.execute('''
        CREATE TABLE $tableProductCache (
          barcode    TEXT    PRIMARY KEY,
          name       TEXT    NOT NULL,
          brand      TEXT,
          category   TEXT    NOT NULL,
          image_url  TEXT,
          quantity   TEXT,
          fetched_at INTEGER NOT NULL
        )
      ''');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
