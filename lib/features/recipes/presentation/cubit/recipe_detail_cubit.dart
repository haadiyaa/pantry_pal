import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_matcher.dart';
import 'recipe_detail_state.dart';

class RecipeDetailCubit extends Cubit<RecipeDetailState> {
  RecipeDetailCubit({
    required this.recipeRepository,
    required this.pantryRepository,
    DateTime Function()? nowProvider,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        super(const RecipeDetailState());

  final RecipeRepository recipeRepository;
  final PantryRepository pantryRepository;
  final DateTime Function() _nowProvider;

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
      final activeItems = pantryItems.where((i) => i.quantity > 0).toList();

      final matches = RecipeMatcher.matchAndRank(
        pantryItems: activeItems,
        candidateRecipes: [recipe],
        now: _nowProvider(),
      );

      final match = matches.isNotEmpty ? matches.first : null;

      emit(
        state.copyWith(
          status: RecipeDetailStatus.success,
          recipe: recipe,
          match: match,
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
}

