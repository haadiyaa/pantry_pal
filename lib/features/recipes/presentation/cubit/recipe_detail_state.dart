import 'package:equatable/equatable.dart';

import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_match.dart';

enum RecipeDetailStatus {
  initial,
  loading,
  success,
  failure,
}

class RecipeDetailState extends Equatable {
  const RecipeDetailState({
    this.status = RecipeDetailStatus.initial,
    this.recipe,
    this.match,
    this.isStale = false,
    this.errorMessage,
  });

  final RecipeDetailStatus status;
  final Recipe? recipe;
  final RecipeMatch? match;
  final bool isStale;
  final String? errorMessage;

  bool get isLoading => status == RecipeDetailStatus.loading;
  bool get isSuccess => status == RecipeDetailStatus.success;
  bool get isFailure => status == RecipeDetailStatus.failure;

  RecipeDetailState copyWith({
    RecipeDetailStatus? status,
    Recipe? recipe,
    RecipeMatch? match,
    bool? isStale,
    String? errorMessage,
  }) {
    return RecipeDetailState(
      status: status ?? this.status,
      recipe: recipe ?? this.recipe,
      match: match ?? this.match,
      isStale: isStale ?? this.isStale,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, recipe, match, isStale, errorMessage];
}

