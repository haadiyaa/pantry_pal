import 'package:equatable/equatable.dart';

/// Represents a single ingredient along with its stated culinary measurement.
class RecipeIngredient extends Equatable {
  const RecipeIngredient({
    required this.name,
    required this.measure,
  });

  final String name;
  final String measure;

  @override
  List<Object?> get props => [name, measure];

  @override
  String toString() => '$measure $name'.trim();
}

