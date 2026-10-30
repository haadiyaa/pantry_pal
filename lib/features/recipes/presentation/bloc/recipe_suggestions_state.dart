import 'package:equatable/equatable.dart';

import '../../domain/models/recipe_match.dart';

enum RecipeSuggestionsStatus {
  initial,
  loading,
  success,
  emptyPantry,
  failure,
}

class RecipeSuggestionsState extends Equatable {
  const RecipeSuggestionsState({
    this.status = RecipeSuggestionsStatus.initial,
    this.allMatches = const [],
    this.filteredMatches = const [],
    this.isVegetarianOnly = false,
    this.isExpiringOnly = false,
    this.minMatchPercentage = 0.0,
    this.isStale = false,
    this.isPartial = false,
    this.errorMessage,
  });

  final RecipeSuggestionsStatus status;
  final List<RecipeMatch> allMatches;
  final List<RecipeMatch> filteredMatches;
  final bool isVegetarianOnly;
  final bool isExpiringOnly;
  final double minMatchPercentage;
  final bool isStale;
  final bool isPartial;
  final String? errorMessage;

  bool get isLoading => status == RecipeSuggestionsStatus.loading;
  bool get isSuccess => status == RecipeSuggestionsStatus.success;
  bool get isEmptyPantry => status == RecipeSuggestionsStatus.emptyPantry;
  bool get isFailure => status == RecipeSuggestionsStatus.failure;

  RecipeSuggestionsState copyWith({
    RecipeSuggestionsStatus? status,
    List<RecipeMatch>? allMatches,
    List<RecipeMatch>? filteredMatches,
    bool? isVegetarianOnly,
    bool? isExpiringOnly,
    double? minMatchPercentage,
    bool? isStale,
    bool? isPartial,
    String? errorMessage,
  }) {
    return RecipeSuggestionsState(
      status: status ?? this.status,
      allMatches: allMatches ?? this.allMatches,
      filteredMatches: filteredMatches ?? this.filteredMatches,
      isVegetarianOnly: isVegetarianOnly ?? this.isVegetarianOnly,
      isExpiringOnly: isExpiringOnly ?? this.isExpiringOnly,
      minMatchPercentage: minMatchPercentage ?? this.minMatchPercentage,
      isStale: isStale ?? this.isStale,
      isPartial: isPartial ?? this.isPartial,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allMatches,
        filteredMatches,
        isVegetarianOnly,
        isExpiringOnly,
        minMatchPercentage,
        isStale,
        isPartial,
        errorMessage,
      ];
}

