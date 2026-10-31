import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/stats/domain/models/category_stat.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_period.dart';
import 'package:pantry_pal/features/stats/domain/services/insight_generator.dart';

void main() {
  const generator = InsightGenerator();

  group('InsightGenerator', () {
    test('returns null when total events is fewer than 5 (insufficient data)', () {
      final insight = generator.generate(
        period: StatsPeriod.last7Days,
        totalEvents: 4,
        totalUsedUnits: 4,
        rescuedUnits: 4,
        wastedUnits: 0,
        wasteRate: 0.0,
        categoryBreakdown: const [],
      );

      expect(insight, isNull);
    });

    test('returns zero-waste praise when wastedUnits is 0 and totalEvents >= 5', () {
      final insight = generator.generate(
        period: StatsPeriod.last7Days,
        totalEvents: 6,
        totalUsedUnits: 6,
        rescuedUnits: 6,
        wastedUnits: 0,
        wasteRate: 0.0,
        categoryBreakdown: const [],
      );

      expect(insight, equals('You wasted nothing in the last 7 days!'));
    });

    test('returns category concentration insight when one category accounts for >= 50% of waste', () {
      final breakdown = [
        const CategoryStat(
          category: 'Dairy',
          wastedUnits: 3,
          totalPricePaise: 9000,
          percentage: 0.60, // 60%
        ),
        const CategoryStat(
          category: 'Produce',
          wastedUnits: 2,
          totalPricePaise: 4000,
          percentage: 0.40,
        ),
      ];

      final insight = generator.generate(
        period: StatsPeriod.last30Days,
        totalEvents: 10,
        totalUsedUnits: 5,
        rescuedUnits: 5,
        wastedUnits: 5,
        wasteRate: 0.50,
        categoryBreakdown: breakdown,
      );

      expect(
        insight,
        equals(
          'Dairy is where most of your waste comes from in the last 30 days (60% of wasted items).',
        ),
      );
    });

    test('returns low-waste congratulations when wasteRate < 10%', () {
      final breakdown = [
        const CategoryStat(
          category: 'Snacks',
          wastedUnits: 1,
          totalPricePaise: 2000,
          percentage: 0.25,
        ),
      ];

      final insight = generator.generate(
        period: StatsPeriod.last30Days,
        totalEvents: 20,
        totalUsedUnits: 19,
        rescuedUnits: 18,
        wastedUnits: 1,
        wasteRate: 0.05, // 5%
        categoryBreakdown: breakdown,
      );

      expect(
        insight,
        equals(
          'Great job keeping waste low! Your waste rate is 5.0% in the last 30 days.',
        ),
      );
    });

    test('returns high waste with rescued notice when wasteRate >= 35% and rescuedUnits > 0', () {
      final breakdown = [
        const CategoryStat(
          category: 'Dairy',
          wastedUnits: 2,
          totalPricePaise: 6000,
          percentage: 0.33,
        ),
        const CategoryStat(
          category: 'Produce',
          wastedUnits: 2,
          totalPricePaise: 5000,
          percentage: 0.33,
        ),
        const CategoryStat(
          category: 'Grains',
          wastedUnits: 2,
          totalPricePaise: 8000,
          percentage: 0.33,
        ),
      ];

      final insight = generator.generate(
        period: StatsPeriod.last90Days,
        totalEvents: 15,
        totalUsedUnits: 8,
        rescuedUnits: 6,
        wastedUnits: 6,
        wasteRate: 6 / 14, // ~42.9%
        categoryBreakdown: breakdown,
      );

      expect(
        insight,
        equals(
          'You rescued 6 items before expiry, but waste is currently at 42.9% in the last 90 days.',
        ),
      );
    });

    test('returns general consumption summary for balanced statistics', () {
      final breakdown = [
        const CategoryStat(
          category: 'Dairy',
          wastedUnits: 1,
          totalPricePaise: 3000,
          percentage: 0.33,
        ),
        const CategoryStat(
          category: 'Produce',
          wastedUnits: 1,
          totalPricePaise: 3000,
          percentage: 0.33,
        ),
        const CategoryStat(
          category: 'Bakery',
          wastedUnits: 1,
          totalPricePaise: 3000,
          percentage: 0.33,
        ),
      ];

      final insight = generator.generate(
        period: StatsPeriod.last30Days,
        totalEvents: 12,
        totalUsedUnits: 9,
        rescuedUnits: 0,
        wastedUnits: 3,
        wasteRate: 0.25, // 25% (between 10% and 35%)
        categoryBreakdown: breakdown,
      );

      expect(
        insight,
        equals('You consumed 9 items and threw away 3 in the last 30 days.'),
      );
    });
  });
}

