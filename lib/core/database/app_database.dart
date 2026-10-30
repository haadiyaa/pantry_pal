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
  static const dbVersion = 6;

  static const tablePantryItems = 'pantry_items';
  static const tableProductCache = 'product_cache';
  static const tableRecipeCache = 'recipe_cache';
  static const tableIngredientSearchCache = 'ingredient_search_cache';
  static const tableShoppingItems = 'shopping_items';
  static const tablePantryEvents = 'pantry_events';

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

  /// Fresh install creates the full, current (v4) schema directly.
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
        notes        TEXT,
        price_paise  INTEGER
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

    // Schema v5: Recipe cache table for full meal details
    await db.execute('''
      CREATE TABLE $tableRecipeCache (
        id         TEXT    PRIMARY KEY,
        json       TEXT    NOT NULL,
        fetched_at INTEGER NOT NULL -- epoch milliseconds
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_recipe_cache_fetched ON $tableRecipeCache (fetched_at)',
    );

    // Schema v5: Ingredient search cache table for filtered recipe IDs
    await db.execute('''
      CREATE TABLE $tableIngredientSearchCache (
        keyword         TEXT    PRIMARY KEY,
        recipe_ids_json TEXT    NOT NULL,
        fetched_at      INTEGER NOT NULL -- epoch milliseconds
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_ingredient_cache_fetched ON $tableIngredientSearchCache (fetched_at)',
    );

    // Schema v6: Shopping list table
    await db.execute('''
      CREATE TABLE $tableShoppingItems (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT    NOT NULL,
        normalized_name TEXT    NOT NULL,
        quantity        INTEGER NOT NULL DEFAULT 1,
        category        TEXT    NOT NULL DEFAULT 'Other',
        is_bought       INTEGER NOT NULL DEFAULT 0,
        source_type     TEXT    NOT NULL, -- 'manual', 'used_up', 'recipe'
        source_label    TEXT,
        added_at        INTEGER NOT NULL, -- epoch milliseconds
        bought_at       INTEGER           -- epoch milliseconds
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_shopping_items_normalized_name ON $tableShoppingItems (normalized_name)',
    );
    await db.execute(
      'CREATE INDEX idx_shopping_items_is_bought ON $tableShoppingItems (is_bought)',
    );

    // Schema v6: Pantry events log (for waste statistics in Step 8)
    await db.execute('''
      CREATE TABLE $tablePantryEvents (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name   TEXT    NOT NULL,
        category    TEXT    NOT NULL,
        quantity    INTEGER NOT NULL DEFAULT 1,
        price_paise INTEGER,
        expiry_date INTEGER,          -- epoch milliseconds
        reason      TEXT    NOT NULL, -- 'used', 'wasted', 'deleted'
        occurred_at INTEGER NOT NULL  -- epoch milliseconds
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_pantry_events_occurred_at ON $tablePantryEvents (occurred_at)',
    );
    await db.execute(
      'CREATE INDEX idx_pantry_events_reason ON $tablePantryEvents (reason)',
    );
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
    if (oldVersion < 4) {
      // Version 4: Add price_paise column
      await db.execute(
        'ALTER TABLE $tablePantryItems ADD COLUMN price_paise INTEGER',
      );
    }
    if (oldVersion < 5) {
      // Version 5: Add recipe_cache and ingredient_search_cache tables
      await db.execute('''
        CREATE TABLE $tableRecipeCache (
          id         TEXT    PRIMARY KEY,
          json       TEXT    NOT NULL,
          fetched_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_recipe_cache_fetched ON $tableRecipeCache (fetched_at)',
      );
      await db.execute('''
        CREATE TABLE $tableIngredientSearchCache (
          keyword         TEXT    PRIMARY KEY,
          recipe_ids_json TEXT    NOT NULL,
          fetched_at      INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_ingredient_cache_fetched ON $tableIngredientSearchCache (fetched_at)',
      );
    }
    if (oldVersion < 6) {
      // Version 6: Add shopping_items and pantry_events tables with indexes
      await db.execute('''
        CREATE TABLE $tableShoppingItems (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          name            TEXT    NOT NULL,
          normalized_name TEXT    NOT NULL,
          quantity        INTEGER NOT NULL DEFAULT 1,
          category        TEXT    NOT NULL DEFAULT 'Other',
          is_bought       INTEGER NOT NULL DEFAULT 0,
          source_type     TEXT    NOT NULL,
          source_label    TEXT,
          added_at        INTEGER NOT NULL,
          bought_at       INTEGER
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_shopping_items_normalized_name ON $tableShoppingItems (normalized_name)',
      );
      await db.execute(
        'CREATE INDEX idx_shopping_items_is_bought ON $tableShoppingItems (is_bought)',
      );

      await db.execute('''
        CREATE TABLE $tablePantryEvents (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          item_name   TEXT    NOT NULL,
          category    TEXT    NOT NULL,
          quantity    INTEGER NOT NULL DEFAULT 1,
          price_paise INTEGER,
          expiry_date INTEGER,
          reason      TEXT    NOT NULL,
          occurred_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_pantry_events_occurred_at ON $tablePantryEvents (occurred_at)',
      );
      await db.execute(
        'CREATE INDEX idx_pantry_events_reason ON $tablePantryEvents (reason)',
      );
    }
  }

  /// Cleans up stale recipe and ingredient cache entries older than [maxAge].
  Future<void> cleanOldCache([Duration maxAge = const Duration(days: 30)]) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;
    await db.delete(
      tableRecipeCache,
      where: 'fetched_at < ?',
      whereArgs: [cutoff],
    );
    await db.delete(
      tableIngredientSearchCache,
      where: 'fetched_at < ?',
      whereArgs: [cutoff],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
