import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event_reason.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_period.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_raw_data.dart';
import 'package:pantry_pal/features/stats/domain/services/time_bucketer.dart';

void main() {
  const bucketer = TimeBucketer();

  // Reference now: Wednesday, 2026-10-28 15:30:00 local time
  final fixedNow = DateTime(2026, 10, 28, 15, 30);

  group('TimeBucketer', () {
    test('last7Days produces exactly 7 daily buckets ending today', () {
      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.last7Days,
        now: fixedNow,
        events: const [],
      );

      expect(buckets.length, equals(7));
      expect(buckets.first.start, equals(DateTime(2026, 10, 22)));
      expect(buckets.last.start, equals(DateTime(2026, 10, 28)));
      expect(buckets.last.end, equals(DateTime(2026, 10, 28, 23, 59, 59, 999)));

      for (final b in buckets) {
        expect(b.usedCount, equals(0));
        expect(b.wastedCount, equals(0));
      }
    });

    test('last30Days produces continuous weekly buckets strictly starting on Monday', () {
      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.last30Days,
        now: fixedNow,
        events: const [],
      );

      expect(buckets.isNotEmpty, isTrue);

      for (final b in buckets) {
        // Monday is weekday 1
        expect(b.start.weekday, equals(DateTime.monday));
        // Sunday is weekday 7
        expect(b.end.weekday, equals(DateTime.sunday));
        // Exactly 7 days length
        final duration = b.end.difference(b.start);
        expect(duration.inDays, equals(6)); // Mon 00:00 to Sun 23:59:59 is 6 full days + 23h59m
      }

      // Verify no gaps between consecutive weekly buckets
      for (var i = 0; i < buckets.length - 1; i++) {
        final nextStart = buckets[i + 1].start;
        final currentEnd = buckets[i].end;
        expect(nextStart.difference(currentEnd).inMilliseconds, equals(1));
      }
    });

    test('last90Days produces continuous weekly buckets starting on Monday', () {
      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.last90Days,
        now: fixedNow,
        events: const [],
      );

      expect(buckets.length, greaterThanOrEqualTo(12));
      for (final b in buckets) {
        expect(b.start.weekday, equals(DateTime.monday));
        expect(b.end.weekday, equals(DateTime.sunday));
      }
    });

    test('allTime generates monthly buckets from earliest event to current month', () {
      final earliest = DateTime(2026, 5, 14);
      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.allTime,
        now: fixedNow, // Oct 2026
        events: const [],
        earliestEventDate: earliest,
      );

      // May, Jun, Jul, Aug, Sep, Oct = 6 months
      expect(buckets.length, equals(6));
      expect(buckets.first.start, equals(DateTime(2026, 5, 1)));
      expect(buckets.first.end, equals(DateTime(2026, 5, 31, 23, 59, 59, 999)));
      expect(buckets.last.start, equals(DateTime(2026, 10, 1)));
      expect(buckets.last.end, equals(DateTime(2026, 10, 31, 23, 59, 59, 999)));
    });

    test('correctly tallies used and wasted events into corresponding buckets', () {
      final events = [
        EventDetailRecord(
          occurredAt: DateTime(2026, 10, 24, 12, 0),
          reason: PantryEventReason.used,
          quantity: 2,
          itemName: 'Milk',
          category: 'Dairy',
        ),
        EventDetailRecord(
          occurredAt: DateTime(2026, 10, 24, 18, 0),
          reason: PantryEventReason.wasted,
          quantity: 1,
          itemName: 'Spinach',
          category: 'Vegetables',
        ),
        EventDetailRecord(
          occurredAt: DateTime(2026, 10, 28, 9, 0),
          reason: PantryEventReason.used,
          quantity: 3,
          itemName: 'Bread',
          category: 'Grains',
        ),
        // Deleted events must be completely ignored
        EventDetailRecord(
          occurredAt: DateTime(2026, 10, 24, 10, 0),
          reason: PantryEventReason.deleted,
          quantity: 5,
          itemName: 'Yogurt',
          category: 'Dairy',
        ),
      ];

      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.last7Days,
        now: fixedNow,
        events: events,
      );

      // 2026-10-24 is index 2 (22, 23, 24, 25, 26, 27, 28)
      final oct24Bucket = buckets.firstWhere((b) => b.start.day == 24);
      expect(oct24Bucket.usedCount, equals(2));
      expect(oct24Bucket.wastedCount, equals(1));

      // 2026-10-28 is index 6
      final oct28Bucket = buckets.firstWhere((b) => b.start.day == 28);
      expect(oct28Bucket.usedCount, equals(3));
      expect(oct28Bucket.wastedCount, equals(0));

      // Untouched days have 0 counts
      final oct25Bucket = buckets.firstWhere((b) => b.start.day == 25);
      expect(oct25Bucket.usedCount, equals(0));
      expect(oct25Bucket.wastedCount, equals(0));
    });

    test('handles leap year leap day (Feb 29) without skipping days', () {
      final leapYearNow = DateTime(2028, 3, 2, 12, 0); // 2028 is a leap year
      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.last7Days,
        now: leapYearNow,
        events: const [],
      );

      expect(buckets.length, equals(7));
      final days = buckets.map((b) => b.start.day).toList();
      // Feb 25, 26, 27, 28, 29, Mar 1, Mar 2
      expect(days, equals([25, 26, 27, 28, 29, 1, 2]));
    });

    test('handles daylight saving transition without breaking bucket continuity', () {
      // Simulating stepping across month/DST boundary
      final dstNow = DateTime(2026, 4, 1, 12, 0);
      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.last7Days,
        now: dstNow,
        events: const [],
      );

      expect(buckets.length, equals(7));
      for (var i = 0; i < buckets.length - 1; i++) {
        expect(
          buckets[i + 1].start.difference(buckets[i].end).inMilliseconds,
          equals(1),
        );
      }
    });

    test('handles single data point gracefully without empty bucketing errors', () {
      final singleEvent = [
        EventDetailRecord(
          occurredAt: fixedNow,
          reason: PantryEventReason.used,
          quantity: 1,
          itemName: 'Yogurt',
          category: 'Dairy',
        ),
      ];

      final buckets = bucketer.buildBuckets(
        period: StatsPeriod.last7Days,
        now: fixedNow,
        events: singleEvent,
      );

      expect(buckets.length, equals(7));
      expect(buckets.last.usedCount, equals(1));
    });
  });
}

