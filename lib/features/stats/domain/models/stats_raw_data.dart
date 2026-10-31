import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_event_reason.dart';

/// Aggregation of event metrics per reason (used or wasted).
class ReasonAggregate extends Equatable {
  const ReasonAggregate({
    required this.reason,
    required this.totalUnits,
    required this.pricedUnits,
    required this.totalPricePaise,
  });

  final PantryEventReason reason;
  final int totalUnits;
  final int pricedUnits;
  final int totalPricePaise;

  @override
  List<Object?> get props => [
        reason,
        totalUnits,
        pricedUnits,
        totalPricePaise,
      ];
}

/// Aggregation of wasted units and value per pantry category.
class CategoryAggregate extends Equatable {
  const CategoryAggregate({
    required this.category,
    required this.totalUnits,
    required this.totalPricePaise,
  });

  final String category;
  final int totalUnits;
  final int totalPricePaise;

  @override
  List<Object?> get props => [category, totalUnits, totalPricePaise];
}

/// Aggregation of an item's events from SQL GROUP BY item_name.
class ItemAggregate extends Equatable {
  const ItemAggregate({
    required this.itemName,
    required this.totalUnits,
    required this.totalPricePaise,
    required this.pricedUnits,
  });

  final String itemName;
  final int totalUnits;
  final int totalPricePaise;
  final int pricedUnits;

  @override
  List<Object?> get props => [
        itemName,
        totalUnits,
        totalPricePaise,
        pricedUnits,
      ];
}

/// Lightweight record for individual events used for time bucketing and rescue checks.
class EventDetailRecord extends Equatable {
  const EventDetailRecord({
    required this.occurredAt,
    required this.reason,
    required this.quantity,
    this.pricePaise,
    this.expiryDate,
    required this.itemName,
    required this.category,
  });

  final DateTime occurredAt;
  final PantryEventReason reason;
  final int quantity;
  final int? pricePaise;
  final DateTime? expiryDate;
  final String itemName;
  final String category;

  @override
  List<Object?> get props => [
        occurredAt,
        reason,
        quantity,
        pricePaise,
        expiryDate,
        itemName,
        category,
      ];
}

/// Plain repository query payload supplied to [StatsCalculator].
class StatsRawData extends Equatable {
  const StatsRawData({
    required this.reasonAggregates,
    required this.wastedCategoryAggregates,
    required this.usedItemAggregates,
    required this.wastedItemAggregates,
    required this.eventRecords,
    this.lastWastedAt,
    this.earliestEventAt,
  });

  final List<ReasonAggregate> reasonAggregates;
  final List<CategoryAggregate> wastedCategoryAggregates;
  final List<ItemAggregate> usedItemAggregates;
  final List<ItemAggregate> wastedItemAggregates;
  final List<EventDetailRecord> eventRecords;
  final DateTime? lastWastedAt;
  final DateTime? earliestEventAt;

  int get totalEvents => eventRecords.length;

  static const empty = StatsRawData(
    reasonAggregates: [],
    wastedCategoryAggregates: [],
    usedItemAggregates: [],
    wastedItemAggregates: [],
    eventRecords: [],
  );

  @override
  List<Object?> get props => [
        reasonAggregates,
        wastedCategoryAggregates,
        usedItemAggregates,
        wastedItemAggregates,
        eventRecords,
        lastWastedAt,
        earliestEventAt,
      ];
}

