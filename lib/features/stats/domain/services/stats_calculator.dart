import '../../../inventory/domain/models/pantry_event_reason.dart';
import '../../../recipes/domain/services/ingredient_normalizer.dart';
import '../models/category_stat.dart';
import '../models/item_stat.dart';
import '../models/stats_period.dart';
import '../models/stats_raw_data.dart';
import '../models/stats_summary.dart';
import 'insight_generator.dart';
import 'time_bucketer.dart';

/// Pure functional calculation engine producing the [StatsSummary].
///
/// Rules:
/// - Rescued: reason == used and occurred_at <= end of expiryDate local day.
/// - Used late: reason == used and occurred_at > end of expiryDate local day.
/// - Deleted: reason == deleted is excluded from all counts and stats.
/// - Waste rate: wasted units / (used units + wasted units); null if denominator is zero.
/// - Value: only events with non-null price contribute; value is integer paise.
/// - Top items: grouped by IngredientNormalizer normalized key.
/// - Zero Flutter framework or plugin imports.
class StatsCalculator {
  const StatsCalculator({
    TimeBucketer? timeBucketer,
    InsightGenerator? insightGenerator,
  })  : _timeBucketer = timeBucketer ?? const TimeBucketer(),
        _insightGenerator = insightGenerator ?? const InsightGenerator();

  final TimeBucketer _timeBucketer;
  final InsightGenerator _insightGenerator;

  StatsSummary calculate({
    required StatsRawData rawData,
    required StatsPeriod period,
    required DateTime now,
  }) {
    final localNow = now.toLocal();

    var rescuedUnits = 0;
    var usedLateUnits = 0;
    var totalWastedUnits = 0;
    var valueUsedPaise = 0;
    var usedPricedUnits = 0;
    var valueWastedPaise = 0;
    var wastedPricedUnits = 0;

    for (final record in rawData.eventRecords) {
      if (record.reason == PantryEventReason.deleted) continue;

      if (record.reason == PantryEventReason.used) {
        final isRescued = _isRescued(record);
        if (isRescued) {
          rescuedUnits += record.quantity;
        } else {
          usedLateUnits += record.quantity;
        }

        if (record.pricePaise != null) {
          valueUsedPaise += record.pricePaise! * record.quantity;
          usedPricedUnits += record.quantity;
        }
      } else if (record.reason == PantryEventReason.wasted) {
        totalWastedUnits += record.quantity;

        if (record.pricePaise != null) {
          valueWastedPaise += record.pricePaise! * record.quantity;
          wastedPricedUnits += record.quantity;
        }
      }
    }

    final totalUsedUnits = rescuedUnits + usedLateUnits;
    final totalUnits = totalUsedUnits + totalWastedUnits;
    final double? wasteRate =
        totalUnits > 0 ? (totalWastedUnits / totalUnits) : null;

    // Days since last waste (calculated in local calendar days)
    final int? daysSinceLastWaste = rawData.lastWastedAt != null
        ? _calculateDaysSince(rawData.lastWastedAt!.toLocal(), localNow)
        : null;

    // Time buckets
    final timeBuckets = _timeBucketer.buildBuckets(
      period: period,
      now: localNow,
      events: rawData.eventRecords,
      earliestEventDate: rawData.earliestEventAt,
    );

    // Category breakdown
    final categoryBreakdown = _buildCategoryBreakdown(
      rawData.wastedCategoryAggregates,
      totalWastedUnits,
    );

    // Top 5 used items and top 5 wasted items
    final topUsedItems = _buildTopItems(rawData.usedItemAggregates);
    final topWastedItems = _buildTopItems(rawData.wastedItemAggregates);

    // Insight
    final insight = _insightGenerator.generate(
      period: period,
      totalEvents: rawData.totalEvents,
      totalUsedUnits: totalUsedUnits,
      rescuedUnits: rescuedUnits,
      wastedUnits: totalWastedUnits,
      wasteRate: wasteRate,
      categoryBreakdown: categoryBreakdown,
    );

    return StatsSummary(
      period: period,
      totalEvents: rawData.totalEvents,
      rescuedUnits: rescuedUnits,
      usedLateUnits: usedLateUnits,
      wastedUnits: totalWastedUnits,
      wasteRate: wasteRate,
      valueUsedPaise: valueUsedPaise,
      usedPricedUnits: usedPricedUnits,
      valueWastedPaise: valueWastedPaise,
      wastedPricedUnits: wastedPricedUnits,
      daysSinceLastWaste: daysSinceLastWaste,
      timeBuckets: timeBuckets,
      categoryBreakdown: categoryBreakdown,
      topWastedItems: topWastedItems,
      topUsedItems: topUsedItems,
      insight: insight,
    );
  }

  /// Whether an item was used on or before its local expiry day (end of that day).
  bool _isRescued(EventDetailRecord record) {
    if (record.expiryDate == null) {
      // Items without expiry date count as rescued when used
      return true;
    }

    final expLocal = record.expiryDate!.toLocal();
    final endOfExpiryDay = DateTime(
      expLocal.year,
      expLocal.month,
      expLocal.day,
      23,
      59,
      59,
      999,
    );

    final eventLocal = record.occurredAt.toLocal();
    return eventLocal.isBefore(endOfExpiryDay) ||
        eventLocal.isAtSameMomentAs(endOfExpiryDay);
  }

  int _calculateDaysSince(DateTime eventDate, DateTime now) {
    final eventMidnight = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final nowMidnight = DateTime(now.year, now.month, now.day);
    final diff = nowMidnight.difference(eventMidnight).inDays;
    return diff >= 0 ? diff : 0;
  }

  List<CategoryStat> _buildCategoryBreakdown(
    List<CategoryAggregate> aggregates,
    int totalWastedUnits,
  ) {
    final list = aggregates.map((agg) {
      final pct = totalWastedUnits > 0
          ? (agg.totalUnits / totalWastedUnits)
          : 0.0;
      return CategoryStat(
        category: agg.category,
        wastedUnits: agg.totalUnits,
        totalPricePaise: agg.totalPricePaise,
        percentage: pct,
      );
    }).toList();

    list.sort((a, b) => b.wastedUnits.compareTo(a.wastedUnits));
    return list;
  }

  List<ItemStat> _buildTopItems(List<ItemAggregate> aggregates) {
    // Group aggregates by normalized name using IngredientNormalizer
    final grouped = <String, _MutableItemStat>{};

    for (final agg in aggregates) {
      final raw = agg.itemName.trim();
      final normalized = IngredientNormalizer.normalize(raw);
      final key = normalized.isNotEmpty ? normalized : raw.toLowerCase();

      final existing = grouped[key];
      if (existing != null) {
        existing.units += agg.totalUnits;
        existing.totalPricePaise += agg.totalPricePaise;
        existing.pricedUnits += agg.pricedUnits;
      } else {
        grouped[key] = _MutableItemStat(
          displayName: raw,
          units: agg.totalUnits,
          totalPricePaise: agg.totalPricePaise,
          pricedUnits: agg.pricedUnits,
        );
      }
    }

    final sorted = grouped.values.map((m) {
      return ItemStat(
        name: m.displayName,
        units: m.units,
        totalPricePaise: m.totalPricePaise,
        pricedUnits: m.pricedUnits,
      );
    }).toList();

    sorted.sort((a, b) {
      final unitComp = b.units.compareTo(a.units);
      if (unitComp != 0) return unitComp;
      return b.totalPricePaise.compareTo(a.totalPricePaise);
    });

    return sorted.take(5).toList();
  }
}

class _MutableItemStat {
  _MutableItemStat({
    required this.displayName,
    required this.units,
    required this.totalPricePaise,
    required this.pricedUnits,
  });

  String displayName;
  int units;
  int totalPricePaise;
  int pricedUnits;
}

