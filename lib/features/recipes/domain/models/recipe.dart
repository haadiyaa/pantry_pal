import 'package:equatable/equatable.dart';

import 'recipe_ingredient.dart';

/// Full recipe domain model containing instructions, media, and ingredients.
class Recipe extends Equatable {
  const Recipe({
    required this.id,
    required this.name,
    required this.category,
    required this.area,
    required this.instructions,
    this.imageUrl,
    this.youtubeUrl,
    this.ingredients = const [],
  });

  final String id;
  final String name;
  final String category;
  final String area;
  final String instructions;
  final String? imageUrl;
  final String? youtubeUrl;
  final List<RecipeIngredient> ingredients;

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        area,
        instructions,
        imageUrl,
        youtubeUrl,
        ingredients,
      ];
}

