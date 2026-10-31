import '../../../../core/database/app_database.dart';
import '../../../inventory/domain/models/pantry_event.dart';
import '../../../inventory/domain/models/pantry_event_reason.dart';
import '../../domain/models/stats_raw_data.dart';
import '../../domain/repositories/stats_repository.dart';
import '../../domain/services/stats_sample_data_generator.dart';

/// SQLite implementation of [StatsRepository] executing parameterized aggregate queries.
class SqliteStatsRepository implements StatsRepository {
  SqliteStatsRepository([AppDatabase? appDb])
      : _appDb = appDb ?? AppDatabase.instance;

  final AppDatabase _appDb;

  @override
  Future<StatsRawData> getStatsData({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await _appDb.database;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // 1. Reason aggregates (used vs wasted totals)
    final reasonRows = await db.rawQuery('''
      SELECT reason,
             SUM(quantity) as total_units,
             SUM(CASE WHEN price_paise IS NOT NULL THEN quantity ELSE 0 END) as priced_units,
             SUM(CASE WHEN price_paise IS NOT NULL THEN price_paise * quantity ELSE 0 END) as total_price_paise
      FROM ${AppDatabase.tablePantryEvents}
      WHERE reason != 'deleted' AND occurred_at >= ? AND occurred_at <= ?
      GROUP BY reason
    ''', [startMs, endMs]);

    final reasonAggregates = reasonRows.map((row) {
      final reasonStr = row['reason'] as String;
      final reason = PantryEventReason.fromStorageKey(reasonStr);
      return ReasonAggregate(
        reason: reason,
        totalUnits: (row['total_units'] as num?)?.toInt() ?? 0,
        pricedUnits: (row['priced_units'] as num?)?.toInt() ?? 0,
        totalPricePaise: (row['total_price_paise'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // 2. Wasted category aggregates
    final categoryRows = await db.rawQuery('''
      SELECT category,
             SUM(quantity) as total_units,
             SUM(CASE WHEN price_paise IS NOT NULL THEN price_paise * quantity ELSE 0 END) as total_price_paise
      FROM ${AppDatabase.tablePantryEvents}
      WHERE reason = 'wasted' AND occurred_at >= ? AND occurred_at <= ?
      GROUP BY category
      ORDER BY total_units DESC
    ''', [startMs, endMs]);

    final wastedCategoryAggregates = categoryRows.map((row) {
      return CategoryAggregate(
        category: (row['category'] as String?) ?? 'Other',
        totalUnits: (row['total_units'] as num?)?.toInt() ?? 0,
        totalPricePaise: (row['total_price_paise'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // 3. Used items aggregates for Top Used list
    final usedItemRows = await db.rawQuery('''
      SELECT item_name,
             SUM(quantity) as total_units,
             SUM(CASE WHEN price_paise IS NOT NULL THEN price_paise * quantity ELSE 0 END) as total_price_paise,
             SUM(CASE WHEN price_paise IS NOT NULL THEN quantity ELSE 0 END) as priced_units
      FROM ${AppDatabase.tablePantryEvents}
      WHERE reason = 'used' AND occurred_at >= ? AND occurred_at <= ?
      GROUP BY item_name
      ORDER BY total_units DESC
      LIMIT 50
    ''', [startMs, endMs]);

    final usedItemAggregates = usedItemRows.map((row) {
      return ItemAggregate(
        itemName: row['item_name'] as String,
        totalUnits: (row['total_units'] as num?)?.toInt() ?? 0,
        totalPricePaise: (row['total_price_paise'] as num?)?.toInt() ?? 0,
        pricedUnits: (row['priced_units'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // 4. Wasted items aggregates for Top Wasted list
    final wastedItemRows = await db.rawQuery('''
      SELECT item_name,
             SUM(quantity) as total_units,
             SUM(CASE WHEN price_paise IS NOT NULL THEN price_paise * quantity ELSE 0 END) as total_price_paise,
             SUM(CASE WHEN price_paise IS NOT NULL THEN quantity ELSE 0 END) as priced_units
      FROM ${AppDatabase.tablePantryEvents}
      WHERE reason = 'wasted' AND occurred_at >= ? AND occurred_at <= ?
      GROUP BY item_name
      ORDER BY total_units DESC
      LIMIT 50
    ''', [startMs, endMs]);

    final wastedItemAggregates = wastedItemRows.map((row) {
      return ItemAggregate(
        itemName: row['item_name'] as String,
        totalUnits: (row['total_units'] as num?)?.toInt() ?? 0,
        totalPricePaise: (row['total_price_paise'] as num?)?.toInt() ?? 0,
        pricedUnits: (row['priced_units'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    // 5. Individual events in the range for time bucketing and rescue evaluations
    final eventRows = await db.query(
      AppDatabase.tablePantryEvents,
      columns: [
        'occurred_at',
        'reason',
        'quantity',
        'price_paise',
        'expiry_date',
        'item_name',
        'category',
      ],
      where: "reason != 'deleted' AND occurred_at >= ? AND occurred_at <= ?",
      whereArgs: [startMs, endMs],
      orderBy: 'occurred_at ASC',
    );

    final eventRecords = eventRows.map((row) {
      return EventDetailRecord(
        occurredAt: DateTime.fromMillisecondsSinceEpoch(row['occurred_at'] as int),
        reason: PantryEventReason.fromStorageKey(row['reason'] as String),
        quantity: (row['quantity'] as int?) ?? 1,
        pricePaise: row['price_paise'] as int?,
        expiryDate: row['expiry_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(row['expiry_date'] as int)
            : null,
        itemName: row['item_name'] as String,
        category: row['category'] as String,
      );
    }).toList();

    // 6. Most recent wasted event date all-time up to [end]
    final lastWastedRows = await db.rawQuery('''
      SELECT MAX(occurred_at) as last_wasted
      FROM ${AppDatabase.tablePantryEvents}
      WHERE reason = 'wasted' AND occurred_at <= ?
    ''', [endMs]);

    final lastWastedMs = lastWastedRows.firstOrNull?['last_wasted'] as int?;
    final lastWastedAt = lastWastedMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastWastedMs)
        : null;

    // 7. Earliest non-deleted event all-time (for allTime month bucketing start)
    final earliestRows = await db.rawQuery('''
      SELECT MIN(occurred_at) as earliest_event
      FROM ${AppDatabase.tablePantryEvents}
      WHERE reason != 'deleted'
    ''');
    final earliestMs = earliestRows.firstOrNull?['earliest_event'] as int?;
    final earliestEventAt = earliestMs != null
        ? DateTime.fromMillisecondsSinceEpoch(earliestMs)
        : null;

    return StatsRawData(
      reasonAggregates: reasonAggregates,
      wastedCategoryAggregates: wastedCategoryAggregates,
      usedItemAggregates: usedItemAggregates,
      wastedItemAggregates: wastedItemAggregates,
      eventRecords: eventRecords,
      lastWastedAt: lastWastedAt,
      earliestEventAt: earliestEventAt,
    );
  }

  @override
  Future<void> insertSampleEvents(List<PantryEvent> events) async {
    final db = await _appDb.database;
    await db.transaction((txn) async {
      for (final event in events) {
        final map = event.toMap()..remove('id');
        await txn.insert(AppDatabase.tablePantryEvents, map);
      }
    });
  }

  @override
  Future<int> clearSampleEvents() async {
    final db = await _appDb.database;
    return db.delete(
      AppDatabase.tablePantryEvents,
      where: 'item_name LIKE ?',
      whereArgs: ['${StatsSampleDataGenerator.sampleTag}%'],
    );
  }
}
