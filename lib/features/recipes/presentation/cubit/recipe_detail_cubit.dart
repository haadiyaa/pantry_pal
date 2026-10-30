import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../data/repositories/shared_preferences_staples_repository.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/repositories/staples_repository.dart';
import '../../domain/services/ingredient_normalizer.dart';
import '../../domain/services/recipe_matcher.dart';
import 'recipe_detail_state.dart';

class RecipeDetailCubit extends Cubit<RecipeDetailState> {
  RecipeDetailCubit({
    required this.recipeRepository,
    required this.pantryRepository,
    StaplesRepository? staplesRepository,
    DateTime Function()? nowProvider,
  })  : _staplesRepository =
            staplesRepository ?? SharedPreferencesStaplesRepository(),
        _nowProvider = nowProvider ?? DateTime.now,
        super(const RecipeDetailState());

  final RecipeRepository recipeRepository;
  final PantryRepository pantryRepository;
  final StaplesRepository _staplesRepository;
  final DateTime Function() _nowProvider;

  List<PantryItem> _cachedPantryItems = const [];

  Future<void> loadRecipe(String recipeId) async {
    emit(state.copyWith(status: RecipeDetailStatus.loading));

    try {
      final detailResult = await recipeRepository.getRecipeById(recipeId);
      final recipe = detailResult.recipe;

      if (recipe == null) {
        emit(
          state.copyWith(
            status: RecipeDetailStatus.failure,
            errorMessage: 'Recipe not found.',
          ),
        );
        return;
      }

      final pantryItems = await pantryRepository.getAll();
      _cachedPantryItems = pantryItems.where((i) => i.quantity > 0).toList();
      final unavailableStaples = await _staplesRepository.getUnavailableStaples();

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: _cachedPantryItems,
        candidateRecipes: [recipe],
        now: _nowProvider(),
        unavailableStaples: unavailableStaples,
      );
      final match = matches.isNotEmpty ? matches.first : null;

      final detailMatch = RecipeMatcher.evaluateDetail(
        recipe: recipe,
        pantryItems: _cachedPantryItems,
        unavailableStaples: unavailableStaples,
        userMarkedAvailable: state.userMarkedAvailable,
        now: _nowProvider(),
      );

      emit(
        state.copyWith(
          status: RecipeDetailStatus.success,
          recipe: recipe,
          match: match,
          detailMatch: detailMatch,
          unavailableStaples: unavailableStaples,
          isStale: detailResult.isStale,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RecipeDetailStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Toggles the temporary "I have this" mark for a non-pantry ingredient.
  /// Held in memory for this recipe only; resets when leaving the screen.
  void toggleUserMark(String ingredientName) {
    if (state.recipe == null) return;

    final normalized = IngredientNormalizer.normalize(ingredientName);
    final key = normalized.isNotEmpty ? normalized : ingredientName.toLowerCase().trim();

    final updatedMarks = Set<String>.from(state.userMarkedAvailable);
    if (updatedMarks.contains(key)) {
      updatedMarks.remove(key);
    } else {
      updatedMarks.add(key);
    }

    final detailMatch = RecipeMatcher.evaluateDetail(
      recipe: state.recipe!,
      pantryItems: _cachedPantryItems,
      unavailableStaples: state.unavailableStaples,
      userMarkedAvailable: updatedMarks,
      now: _nowProvider(),
    );

    emit(
      state.copyWith(
        userMarkedAvailable: updatedMarks,
        detailMatch: detailMatch,
      ),
    );
  }

  /// Toggles availability of a kitchen staple (e.g. out of cooking oil).
  /// Persisted globally in SharedPreferences across all recipes.
  Future<void> toggleStapleAvailability(String stapleName) async {
    if (state.recipe == null) return;

    final normalized = IngredientNormalizer.normalize(stapleName);
    final key = normalized.isNotEmpty ? normalized : stapleName.toLowerCase().trim();
    final isCurrentlyUnavailable = state.unavailableStaples.contains(key);

    // If currently unavailable, mark available (true); otherwise mark unavailable (false)
    await _staplesRepository.setStapleAvailability(
      key,
      isCurrentlyUnavailable,
    );

    final updatedUnavailable = await _staplesRepository.getUnavailableStaples();

    final detailMatch = RecipeMatcher.evaluateDetail(
      recipe: state.recipe!,
      pantryItems: _cachedPantryItems,
      unavailableStaples: updatedUnavailable,
      userMarkedAvailable: state.userMarkedAvailable,
      now: _nowProvider(),
    );

    final matches = RecipeMatcher.matchAndRank(
      pantryItems: _cachedPantryItems,
      candidateRecipes: [state.recipe!],
      now: _nowProvider(),
      unavailableStaples: updatedUnavailable,
    );

    emit(
      state.copyWith(
        unavailableStaples: updatedUnavailable,
        detailMatch: detailMatch,
        match: matches.isNotEmpty ? matches.first : state.match,
      ),
    );
  }

  /// Reloads pantry items from repository (e.g. after adding an item to pantry)
  /// and recomputes the detail match immediately.
  Future<void> refresh() async {
    if (state.recipe == null) return;

    final pantryItems = await pantryRepository.getAll();
    _cachedPantryItems = pantryItems.where((i) => i.quantity > 0).toList();
    final unavailableStaples = await _staplesRepository.getUnavailableStaples();

    final matches = RecipeMatcher.matchAndRank(
      pantryItems: _cachedPantryItems,
      candidateRecipes: [state.recipe!],
      now: _nowProvider(),
      unavailableStaples: unavailableStaples,
    );

    final detailMatch = RecipeMatcher.evaluateDetail(
      recipe: state.recipe!,
      pantryItems: _cachedPantryItems,
      unavailableStaples: unavailableStaples,
      userMarkedAvailable: state.userMarkedAvailable,
      now: _nowProvider(),
    );

    emit(
      state.copyWith(
        match: matches.isNotEmpty ? matches.first : null,
        detailMatch: detailMatch,
        unavailableStaples: unavailableStaples,
      ),
    );
  }
}
