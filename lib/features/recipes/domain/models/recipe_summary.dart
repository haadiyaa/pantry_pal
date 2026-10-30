import 'package:equatable/equatable.dart';

/// Lightweight summary model returned by TheMealDB filter endpoints.
class RecipeSummary extends Equatable {
  const RecipeSummary({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? imageUrl;

  @override
  List<Object?> get props => [id, name, imageUrl];
}

