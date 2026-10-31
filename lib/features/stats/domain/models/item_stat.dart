import 'package:equatable/equatable.dart';

/// Aggregated item statistics for the "Most wasted items" and "Most used items" lists.
/// Items are grouped by normalized name (e.g. "Curd" and "Yogurt" merge).
class ItemStat extends Equatable {
  const ItemStat({
    required this.name,
    required this.units,
    required this.totalPricePaise,
    required this.pricedUnits,
  });

  final String name;
  final int units;
  final int totalPricePaise;
  final int pricedUnits;

  bool get hasPrice => pricedUnits > 0;

  @override
  List<Object?> get props => [
        name,
        units,
        totalPricePaise,
        pricedUnits,
      ];
}

