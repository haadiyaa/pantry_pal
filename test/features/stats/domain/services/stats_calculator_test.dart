import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event_reason.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_period.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_raw_data.dart';
import 'package:pantry_pal/features/stats/domain/services/stats_calculator.dart';

void main() {
  const calculator = StatsCalculator();
  final fixedNow = DateTime(2026, 6, 15, 12, 0);

  group('StatsCalculator', () {
    test('zero events gives null waste rate and empty metrics', () {
      final summary = calculator.calculate(
        rawData: StatsRawData.empty,
        period: StatsPeriod.last30Days,
        now: fixedNow,
      );

      expect(summary.totalEvents, equals(0));
      expect(summary.rescuedUnits, equals(0));
      expect(summary.usedLateUnits, equals(0));
      expect(summary.totalUsedUnits, equals(0));
      expect(summary.wastedUnits, equals(0));
      expect(summary.wasteRate, isNull);
      expect(summary.valueUsedPaise, equals(0));
      expect(summary.valueWastedPaise, equals(0));
      expect(summary.daysSinceLastWaste, isNull);
      expect(summary.isEmpty, isTrue);
      expect(summary.usedCoverageNote, equals('No items consumed'));
      expect(summary.wastedCoverageNote, equals('No items wasted'));
    });

    test('only used events calculates 0% waste rate and rescued split', () {
      final rawData = StatsRawData(
        reasonAggregates: const [
          ReasonAggregate(
            reason: PantryEventReason.used,
            totalUnits: 3,
            pricedUnits: 3,
            totalPricePaise: 9000,
          ),
        ],
        wastedCategoryAggregates: const [],
        usedItemAggregates: const [
          ItemAggregate(
            itemName: 'Milk',
            totalUnits: 3,
            totalPricePaise: 9000,
            pricedUnits: 3,
          ),
        ],
        wastedItemAggregates: const [],
        eventRecords: [
          // Rescued: used 2 days before expiry
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 10, 10, 0),
            reason: PantryEventReason.used,
            quantity: 2,
            pricePaise: 3000,
            expiryDate: DateTime(2026, 6, 12),
            itemName: 'Milk',
            category: 'Dairy',
          ),
          // Rescued on the exact expiry day (at 21:00, expiry day end is 23:59:59)
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 12, 21, 0),
            reason: PantryEventReason.used,
            quantity: 1,
            pricePaise: 3000,
            expiryDate: DateTime(2026, 6, 12),
            itemName: 'Milk',
            category: 'Dairy',
          ),
        ],
      );

      final summary = calculator.calculate(
        rawData: rawData,
        period: StatsPeriod.last7Days,
        now: fixedNow,
      );

      expect(summary.totalEvents, equals(2));
      expect(summary.rescuedUnits, equals(3));
      expect(summary.usedLateUnits, equals(0));
      expect(summary.totalUsedUnits, equals(3));
      expect(summary.wastedUnits, equals(0));
      expect(summary.wasteRate, equals(0.0));
      expect(summary.valueUsedPaise, equals(9000));
      expect(summary.valueWastedPaise, equals(0));
    });

    test('used after expiry day counts as used late (not rescued)', () {
      final rawData = StatsRawData(
        reasonAggregates: const [],
        wastedCategoryAggregates: const [],
        usedItemAggregates: const [],
        wastedItemAggregates: const [],
        eventRecords: [
          // Used 1 day after expiry
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 13, 9, 0),
            reason: PantryEventReason.used,
            quantity: 2,
            expiryDate: DateTime(2026, 6, 12),
            itemName: 'Bread',
            category: 'Grains',
          ),
        ],
      );

      final summary = calculator.calculate(
        rawData: rawData,
        period: StatsPeriod.last7Days,
        now: fixedNow,
      );

      expect(summary.rescuedUnits, equals(0));
      expect(summary.usedLateUnits, equals(2));
      expect(summary.totalUsedUnits, equals(2));
    });

    test('only wasted events calculates 100% waste rate and value wasted', () {
      final rawData = StatsRawData(
        reasonAggregates: const [],
        wastedCategoryAggregates: const [
          CategoryAggregate(
            category: 'Dairy',
            totalUnits: 2,
            totalPricePaise: 8000,
          ),
        ],
        usedItemAggregates: const [],
        wastedItemAggregates: const [
          ItemAggregate(
            itemName: 'Paneer',
            totalUnits: 2,
            totalPricePaise: 8000,
            pricedUnits: 2,
          ),
        ],
        eventRecords: [
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 14, 15, 0),
            reason: PantryEventReason.wasted,
            quantity: 2,
            pricePaise: 4000,
            itemName: 'Paneer',
            category: 'Dairy',
          ),
        ],
        lastWastedAt: DateTime(2026, 6, 14, 15, 0),
      );

      final summary = calculator.calculate(
        rawData: rawData,
        period: StatsPeriod.last7Days,
        now: fixedNow, // 2026-06-15
      );

      expect(summary.totalUsedUnits, equals(0));
      expect(summary.wastedUnits, equals(2));
      expect(summary.wasteRate, equals(1.0));
      expect(summary.valueWastedPaise, equals(8000));
      expect(summary.wastedPricedUnits, equals(2));
      expect(summary.wastedCoverageNote, equals('Based on 2 of 2 items with a price'));
      expect(summary.daysSinceLastWaste, equals(1)); // 1 day since June 14
    });

    test('deleted reason is excluded from all counts and statistics', () {
      final rawData = StatsRawData(
        reasonAggregates: const [],
        wastedCategoryAggregates: const [],
        usedItemAggregates: const [],
        wastedItemAggregates: const [],
        eventRecords: [
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 10),
            reason: PantryEventReason.deleted,
            quantity: 10,
            pricePaise: 50000,
            itemName: 'Typo Mistake',
            category: 'Other',
          ),
        ],
      );

      final summary = calculator.calculate(
        rawData: rawData,
        period: StatsPeriod.last7Days,
        now: fixedNow,
      );

      expect(summary.totalUsedUnits, equals(0));
      expect(summary.wastedUnits, equals(0));
      expect(summary.wasteRate, isNull);
      expect(summary.valueUsedPaise, equals(0));
      expect(summary.valueWastedPaise, equals(0));
    });

    test('mixed events calculate correct waste rate and partial price coverage', () {
      final rawData = StatsRawData(
        reasonAggregates: const [],
        wastedCategoryAggregates: const [
          CategoryAggregate(
            category: 'Vegetables',
            totalUnits: 1,
            totalPricePaise: 2500,
          ),
        ],
        usedItemAggregates: const [],
        wastedItemAggregates: const [],
        eventRecords: [
          // 2 used units with price ₹30 each = ₹60
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 10),
            reason: PantryEventReason.used,
            quantity: 2,
            pricePaise: 3000,
            expiryDate: DateTime(2026, 6, 12),
            itemName: 'Milk',
            category: 'Dairy',
          ),
          // 1 used unit WITHOUT price
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 11),
            reason: PantryEventReason.used,
            quantity: 1,
            pricePaise: null,
            expiryDate: DateTime(2026, 6, 13),
            itemName: 'Banana',
            category: 'Fruits',
          ),
          // 1 wasted unit with price ₹25
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 12),
            reason: PantryEventReason.wasted,
            quantity: 1,
            pricePaise: 2500,
            itemName: 'Spinach',
            category: 'Vegetables',
          ),
        ],
      );

      final summary = calculator.calculate(
        rawData: rawData,
        period: StatsPeriod.last7Days,
        now: fixedNow,
      );

      // totalUsed = 3, wasted = 1 -> wasteRate = 1 / (3 + 1) = 0.25 (25%)
      expect(summary.totalUsedUnits, equals(3));
      expect(summary.wastedUnits, equals(1));
      expect(summary.wasteRate, equals(0.25));

      // Value used: 2 units * 3000 = 6000 paise (₹60.00). 2 of 3 units priced.
      expect(summary.valueUsedPaise, equals(6000));
      expect(summary.usedPricedUnits, equals(2));
      expect(summary.usedCoverageNote, equals('Based on 2 of 3 items with a price'));

      // Value wasted: 1 unit * 2500 = 2500 paise (₹25.00). 1 of 1 unit priced.
      expect(summary.valueWastedPaise, equals(2500));
      expect(summary.wastedPricedUnits, equals(1));
      expect(summary.wastedCoverageNote, equals('Based on 1 of 1 items with a price'));
    });

    test('quantities greater than 1 multiply value and units correctly', () {
      final rawData = StatsRawData(
        reasonAggregates: const [],
        wastedCategoryAggregates: const [],
        usedItemAggregates: const [],
        wastedItemAggregates: const [],
        eventRecords: [
          EventDetailRecord(
            occurredAt: DateTime(2026, 6, 10),
            reason: PantryEventReason.wasted,
            quantity: 4,
            pricePaise: 5000, // ₹50 each * 4 = ₹200 (20000 paise)
            itemName: 'Apples',
            category: 'Fruits',
          ),
        ],
      );

      final summary = calculator.calculate(
        rawData: rawData,
        period: StatsPeriod.last7Days,
        now: fixedNow,
      );

      expect(summary.wastedUnits, equals(4));
      expect(summary.wastedPricedUnits, equals(4));
      expect(summary.valueWastedPaise, equals(20000));
    });

    test('top items merges synonyms by normalized name (Curd and Yogurt)', () {
      final rawData = StatsRawData(
        reasonAggregates: const [],
        wastedCategoryAggregates: const [],
        usedItemAggregates: const [],
        wastedItemAggregates: const [
          ItemAggregate(
            itemName: 'Greek Yogurt',
            totalUnits: 3,
            totalPricePaise: 15000,
            pricedUnits: 3,
          ),
          ItemAggregate(
            itemName: 'Curd',
            totalUnits: 2,
            totalPricePaise: 8000,
            pricedUnits: 2,
          ),
          ItemAggregate(
            itemName: 'Bread',
            totalUnits: 1,
            totalPricePaise: 4000,
            pricedUnits: 1,
          ),
        ],
        eventRecords: const [],
      );

      final summary = calculator.calculate(
        rawData: rawData,
        period: StatsPeriod.last30Days,
        now: fixedNow,
      );

      // 'Greek Yogurt' and 'Curd' share the same normalized key 'curd' / 'yogurt'
      // and should merge into a single top item with 3 + 2 = 5 units!
      expect(summary.topWastedItems.length, equals(2));
      final top = summary.topWastedItems.first;
      expect(top.units, equals(5));
      expect(top.totalPricePaise, equals(23000));
    });
  });
}

