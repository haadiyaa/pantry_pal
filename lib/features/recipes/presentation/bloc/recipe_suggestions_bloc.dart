import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../domain/models/recipe_match.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_matcher.dart';
import 'recipe_suggestions_event.dart';
import 'recipe_suggestions_state.dart';

EventTransformer<E> _debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class RecipeSuggestionsBloc
    extends Bloc<RecipeSuggestionsEvent, RecipeSuggestionsState> {
  RecipeSuggestionsBloc({
    required this.pantryRepository,
    required this.recipeRepository,
    DateTime Function()? nowProvider,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        super(const RecipeSuggestionsState()) {
    on<RecipeSuggestionsStarted>(_onStarted);
    on<RecipeSuggestionsRefreshed>(_onRefreshed);
    on<RecipeSuggestionsRetried>(_onRetried);
    on<RecipeSuggestionsVegetarianToggled>(_onVegetarianToggled);
    on<RecipeSuggestionsExpiringOnlyToggled>(_onExpiringOnlyToggled);
    on<RecipeSuggestionsMinMatchChanged>(_onMinMatchChanged);
    on<RecipeSuggestionsInventoryChanged>(
      _onInventoryChanged,
      transformer: _debounce(const Duration(milliseconds: 500)),
    );
  }

  final PantryRepository pantryRepository;
  final RecipeRepository recipeRepository;
  final DateTime Function() _nowProvider;

  Future<void> _onStarted(
    RecipeSuggestionsStarted event,
    Emitter<RecipeSuggestionsState> emit,
  ) async {
    await _loadSuggestions(emit, forceRefresh: false);
  }

  Future<void> _onRefreshed(
    RecipeSuggestionsRefreshed event,
    Emitter<RecipeSuggestionsState> emit,
  ) async {
    await _loadSuggestions(emit, forceRefresh: true);
  }

  Future<void> _onRetried(
    RecipeSuggestionsRetried event,
    Emitter<RecipeSuggestionsState> emit,
  ) async {
    await _loadSuggestions(emit, forceRefresh: false);
  }

  Future<void> _loadSuggestions(
    Emitter<RecipeSuggestionsState> emit, {
    required bool forceRefresh,
  }) async {
    emit(state.copyWith(status: RecipeSuggestionsStatus.loading));

    try {
      final pantryItems = await pantryRepository.getAll();
      final activeItems = pantryItems.where((i) => i.quantity > 0).toList();

      if (activeItems.isEmpty) {
        emit(
          state.copyWith(
            status: RecipeSuggestionsStatus.emptyPantry,
            allMatches: const [],
            filteredMatches: const [],
          ),
        );
        return;
      }

      final queryResult = await recipeRepository.getRecipeSuggestions(
        pantryItems: activeItems,
        forceRefresh: forceRefresh,
      );

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: activeItems,
        candidateRecipes: queryResult.recipes,
        now: _nowProvider(),
      );

      final filtered = _applyFilters(
        matches,
        isVegetarian: state.isVegetarianOnly,
        isExpiringOnly: state.isExpiringOnly,
        minMatch: state.minMatchPercentage,
      );

      emit(
        state.copyWith(
          status: RecipeSuggestionsStatus.success,
          allMatches: matches,
          filteredMatches: filtered,
          isStale: queryResult.isStale,
          isPartial: queryResult.isPartial,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RecipeSuggestionsStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _onVegetarianToggled(
    RecipeSuggestionsVegetarianToggled event,
    Emitter<RecipeSuggestionsState> emit,
  ) {
    final newVeg = !state.isVegetarianOnly;
    final filtered = _applyFilters(
      state.allMatches,
      isVegetarian: newVeg,
      isExpiringOnly: state.isExpiringOnly,
      minMatch: state.minMatchPercentage,
    );
    emit(state.copyWith(isVegetarianOnly: newVeg, filteredMatches: filtered));
  }

  void _onExpiringOnlyToggled(
    RecipeSuggestionsExpiringOnlyToggled event,
    Emitter<RecipeSuggestionsState> emit,
  ) {
    final newExpiring = !state.isExpiringOnly;
    final filtered = _applyFilters(
      state.allMatches,
      isVegetarian: state.isVegetarianOnly,
      isExpiringOnly: newExpiring,
      minMatch: state.minMatchPercentage,
    );
    emit(state.copyWith(isExpiringOnly: newExpiring, filteredMatches: filtered));
  }

  void _onMinMatchChanged(
    RecipeSuggestionsMinMatchChanged event,
    Emitter<RecipeSuggestionsState> emit,
  ) {
    final filtered = _applyFilters(
      state.allMatches,
      isVegetarian: state.isVegetarianOnly,
      isExpiringOnly: state.isExpiringOnly,
      minMatch: event.minMatchPercentage,
    );
    emit(
      state.copyWith(
        minMatchPercentage: event.minMatchPercentage,
        filteredMatches: filtered,
      ),
    );
  }

  Future<void> _onInventoryChanged(
    RecipeSuggestionsInventoryChanged event,
    Emitter<RecipeSuggestionsState> emit,
  ) async {
    final activeItems = event.items.where((i) => i.quantity > 0).toList();
    if (activeItems.isEmpty) {
      emit(
        state.copyWith(
          status: RecipeSuggestionsStatus.emptyPantry,
          allMatches: const [],
          filteredMatches: const [],
        ),
      );
      return;
    }

    if (state.allMatches.isEmpty &&
        state.status == RecipeSuggestionsStatus.emptyPantry) {
      // Transitioned from empty pantry to having items: reload
      await _loadSuggestions(emit, forceRefresh: false);
      return;
    }

    // Re-match against existing candidate recipes without new network storm
    final existingRecipes = state.allMatches.map((m) => m.recipe).toList();
    if (existingRecipes.isNotEmpty) {
      final updatedMatches = RecipeMatcher.matchAndRank(
        pantryItems: activeItems,
        candidateRecipes: existingRecipes,
        now: _nowProvider(),
      );

      final filtered = _applyFilters(
        updatedMatches,
        isVegetarian: state.isVegetarianOnly,
        isExpiringOnly: state.isExpiringOnly,
        minMatch: state.minMatchPercentage,
      );

      emit(
        state.copyWith(
          status: RecipeSuggestionsStatus.success,
          allMatches: updatedMatches,
          filteredMatches: filtered,
        ),
      );
    }
  }

  List<RecipeMatch> _applyFilters(
    List<RecipeMatch> matches, {
    required bool isVegetarian,
    required bool isExpiringOnly,
    required double minMatch,
  }) {
    var result = List<RecipeMatch>.from(matches);

    if (isVegetarian) {
      result = result
          .where((m) => RecipeMatcher.isVegetarian(m.recipe))
          .toList();
    }

    if (isExpiringOnly) {
      result = result.where((m) => m.usesExpiringItems).toList();
    }

    if (minMatch > 0.0) {
      result = result.where((m) => m.matchPercentage >= minMatch).toList();
    }

    return result;
  }
}
