import 'package:equatable/equatable.dart';

/// Aggregated waste statistics for a single pantry category.
class CategoryStat extends Equatable {
  const CategoryStat({
    required this.category,
    required this.wastedUnits,
    required this.totalPricePaise,
    required this.percentage,
  });

  final String category;
  final int wastedUnits;
  final int totalPricePaise;
  final double percentage; // 0.0 to 1.0

  @override
  List<Object?> get props => [
        category,
        wastedUnits,
        totalPricePaise,
        percentage,
      ];
}

