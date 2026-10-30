import 'package:equatable/equatable.dart';

import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_detail_match_result.dart';
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
    this.detailMatch,
    this.userMarkedAvailable = const {},
    this.unavailableStaples = const {},
    this.isStale = false,
    this.errorMessage,
  });

  final RecipeDetailStatus status;
  final Recipe? recipe;
  final RecipeMatch? match;
  final RecipeDetailMatchResult? detailMatch;

  /// Ephemeral per-recipe manual marks ("I have this") held in memory only.
  final Set<String> userMarkedAvailable;

  /// Global staple overrides retrieved from StaplesRepository.
  final Set<String> unavailableStaples;

  final bool isStale;
  final String? errorMessage;

  bool get isLoading => status == RecipeDetailStatus.loading;
  bool get isSuccess => status == RecipeDetailStatus.success;
  bool get isFailure => status == RecipeDetailStatus.failure;

  RecipeDetailState copyWith({
    RecipeDetailStatus? status,
    Recipe? recipe,
    RecipeMatch? match,
    RecipeDetailMatchResult? detailMatch,
    Set<String>? userMarkedAvailable,
    Set<String>? unavailableStaples,
    bool? isStale,
    String? errorMessage,
  }) {
    return RecipeDetailState(
      status: status ?? this.status,
      recipe: recipe ?? this.recipe,
      match: match ?? this.match,
      detailMatch: detailMatch ?? this.detailMatch,
      userMarkedAvailable: userMarkedAvailable ?? this.userMarkedAvailable,
      unavailableStaples: unavailableStaples ?? this.unavailableStaples,
      isStale: isStale ?? this.isStale,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recipe,
        match,
        detailMatch,
        userMarkedAvailable,
        unavailableStaples,
        isStale,
        errorMessage,
      ];
}
