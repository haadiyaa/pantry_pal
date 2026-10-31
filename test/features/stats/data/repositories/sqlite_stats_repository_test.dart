import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' hide equals;
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event_reason.dart';
import 'package:pantry_pal/features/stats/data/repositories/sqlite_stats_repository.dart';
import 'package:pantry_pal/features/stats/domain/services/stats_sample_data_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late AppDatabase appDb;
  late SqliteStatsRepository repo;

  final baseDate = DateTime(2026, 6, 15, 12, 0);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('stats_repo_test_');
    final dbPath = join(tempDir.path, 'stats_test.db');
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      dbPath: dbPath,
    );
    repo = SqliteStatsRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> insertEvent({
    required String itemName,
    required String category,
    required int quantity,
    int? pricePaise,
    DateTime? expiryDate,
    required PantryEventReason reason,
    required DateTime occurredAt,
  }) async {
    final db = await appDb.database;
    await db.insert(AppDatabase.tablePantryEvents, {
      'item_name': itemName,
      'category': category,
      'quantity': quantity,
      'price_paise': pricePaise,
      'expiry_date': expiryDate?.millisecondsSinceEpoch,
      'reason': reason.storageKey,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
    });
  }

  group('SqliteStatsRepository', () {
    test('empty pantry_events table returns empty aggregates without errors', () async {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 30);

      final data = await repo.getStatsData(start: start, end: end);

      expect(data.reasonAggregates, isEmpty);
      expect(data.wastedCategoryAggregates, isEmpty);
      expect(data.usedItemAggregates, isEmpty);
      expect(data.wastedItemAggregates, isEmpty);
      expect(data.eventRecords, isEmpty);
      expect(data.lastWastedAt, isNull);
      expect(data.earliestEventAt, isNull);
      expect(data.totalEvents, equals(0));
    });

    test('filters strictly by occurred_at range', () async {
      // 1 event before range
      await insertEvent(
        itemName: 'Old Milk',
        category: 'Dairy',
        quantity: 1,
        reason: PantryEventReason.used,
        occurredAt: DateTime(2026, 5, 20),
      );

      // 2 events inside range
      await insertEvent(
        itemName: 'Current Yogurt',
        category: 'Dairy',
        quantity: 1,
        reason: PantryEventReason.used,
        occurredAt: DateTime(2026, 6, 10),
      );
      await insertEvent(
        itemName: 'Current Tomatoes',
        category: 'Vegetables',
        quantity: 2,
        reason: PantryEventReason.wasted,
        occurredAt: DateTime(2026, 6, 12),
      );

      // 1 event after range
      await insertEvent(
        itemName: 'Future Bread',
        category: 'Grains',
        quantity: 1,
        reason: PantryEventReason.used,
        occurredAt: DateTime(2026, 7, 5),
      );

      final data = await repo.getStatsData(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );

      // Only the 2 events inside June must be returned
      expect(data.totalEvents, equals(2));
      final names = data.eventRecords.map((e) => e.itemName).toList();
      expect(names, containsAll(['Current Yogurt', 'Current Tomatoes']));
      expect(names, isNot(contains('Old Milk')));
      expect(names, isNot(contains('Future Bread')));
    });

    test('strictly excludes deleted events from all queries and aggregates', () async {
      await insertEvent(
        itemName: 'Valid Used Item',
        category: 'Dairy',
        quantity: 1,
        reason: PantryEventReason.used,
        occurredAt: baseDate,
      );

      await insertEvent(
        itemName: 'Accidental Deleted Item',
        category: 'Snacks',
        quantity: 5,
        pricePaise: 10000,
        reason: PantryEventReason.deleted,
        occurredAt: baseDate,
      );

      final data = await repo.getStatsData(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );

      expect(data.totalEvents, equals(1));
      expect(data.eventRecords.first.itemName, equals('Valid Used Item'));

      // Check reason aggregates: deleted is never present
      expect(data.reasonAggregates.any((r) => r.reason == PantryEventReason.deleted), isFalse);
    });

    test('groups wasted items by category ordered by total_units DESC', () async {
      // 3 units of Produce wasted
      await insertEvent(
        itemName: 'Spinach',
        category: 'Vegetables',
        quantity: 2,
        pricePaise: 2000,
        reason: PantryEventReason.wasted,
        occurredAt: baseDate,
      );
      await insertEvent(
        itemName: 'Carrots',
        category: 'Vegetables',
        quantity: 1,
        pricePaise: 3000,
        reason: PantryEventReason.wasted,
        occurredAt: baseDate,
      );

      // 5 units of Dairy wasted
      await insertEvent(
        itemName: 'Milk',
        category: 'Dairy',
        quantity: 5,
        pricePaise: 3000,
        reason: PantryEventReason.wasted,
        occurredAt: baseDate,
      );

      // Used Dairy (must NOT appear in wasted categories)
      await insertEvent(
        itemName: 'Yogurt',
        category: 'Dairy',
        quantity: 10,
        reason: PantryEventReason.used,
        occurredAt: baseDate,
      );

      final data = await repo.getStatsData(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );

      final wastedCats = data.wastedCategoryAggregates;
      expect(wastedCats.length, equals(2));

      // Dairy (5 units) comes before Vegetables (3 units)
      expect(wastedCats[0].category, equals('Dairy'));
      expect(wastedCats[0].totalUnits, equals(5));

      expect(wastedCats[1].category, equals('Vegetables'));
      expect(wastedCats[1].totalUnits, equals(3));
    });

    test('finds lastWastedAt correctly across history up to end date', () async {
      await insertEvent(
        itemName: 'Old Waste',
        category: 'Dairy',
        quantity: 1,
        reason: PantryEventReason.wasted,
        occurredAt: DateTime(2026, 6, 10, 10, 0),
      );

      await insertEvent(
        itemName: 'Recent Waste',
        category: 'Dairy',
        quantity: 1,
        reason: PantryEventReason.wasted,
        occurredAt: DateTime(2026, 6, 14, 18, 0),
      );

      final data = await repo.getStatsData(
        start: DateTime(2026, 6, 12),
        end: DateTime(2026, 6, 20),
      );

      expect(data.lastWastedAt, equals(DateTime(2026, 6, 14, 18, 0)));
    });

    test('developer sample seeding inserts and clears only sample events', () async {
      // 1. Insert a real user event
      await insertEvent(
        itemName: 'Real User Milk',
        category: 'Dairy',
        quantity: 1,
        reason: PantryEventReason.used,
        occurredAt: baseDate,
      );

      // 2. Insert developer sample events
      final sampleEvents = [
        PantryEvent(
          itemName: '${StatsSampleDataGenerator.sampleTag} Sample Cheese',
          category: 'Dairy',
          quantity: 2,
          reason: PantryEventReason.wasted,
          occurredAt: baseDate,
        ),
        PantryEvent(
          itemName: '${StatsSampleDataGenerator.sampleTag} Sample Bread',
          category: 'Grains',
          quantity: 1,
          reason: PantryEventReason.used,
          occurredAt: baseDate,
        ),
      ];
      await repo.insertSampleEvents(sampleEvents);

      var data = await repo.getStatsData(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );
      expect(data.totalEvents, equals(3));

      // 3. Clear developer sample events
      final deletedCount = await repo.clearSampleEvents();
      expect(deletedCount, equals(2));

      // Verify real user event was preserved!
      data = await repo.getStatsData(
        start: DateTime(2026, 6, 1),
        end: DateTime(2026, 6, 30),
      );
      expect(data.totalEvents, equals(1));
      expect(data.eventRecords.first.itemName, equals('Real User Milk'));
    });
  });
}
