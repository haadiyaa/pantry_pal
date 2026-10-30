import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:pantry_pal/features/recipes/presentation/cubit/recipe_detail_cubit.dart';
import 'package:pantry_pal/features/recipes/presentation/cubit/recipe_detail_state.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

void main() {
  late MockRecipeRepository mockRecipeRepo;
  late MockPantryRepository mockPantryRepo;
  final fixedNow = DateTime(2026, 10, 30, 10, 0);

  const testRecipe = Recipe(
    id: '52772',
    name: 'Teriyaki Chicken Casserole',
    category: 'Chicken',
    area: 'Japanese',
    instructions: 'Preheat oven. Cook chicken with soy sauce and rice.',
    imageUrl: 'https://example.com/chicken.jpg',
    youtubeUrl: 'https://youtube.com/watch?v=123',
    ingredients: [
      RecipeIngredient(name: 'Chicken Breasts', measure: '2'),
      RecipeIngredient(name: 'Soy Sauce', measure: '3/4 cup'),
      RecipeIngredient(name: 'Brown Rice', measure: '2 cups'),
    ],
  );

  final testPantry = [
    PantryItem(
      id: 1,
      name: 'Chicken Breast',
      quantity: 2,
      category: 'Meat and Fish',
      expiryDate: fixedNow.add(const Duration(days: 3)),
      addedAt: fixedNow,
    ),
    PantryItem(
      id: 2,
      name: 'Soy Sauce',
      quantity: 1,
      category: 'Other',
      expiryDate: fixedNow.add(const Duration(days: 60)),
      addedAt: fixedNow,
    ),
  ];

  setUp(() {
    mockRecipeRepo = MockRecipeRepository();
    mockPantryRepo = MockPantryRepository();
  });

  group('RecipeDetailCubit', () {
    test('initial state has initial status and null recipe', () {
      final cubit = RecipeDetailCubit(
        recipeRepository: mockRecipeRepo,
        pantryRepository: mockPantryRepo,
        nowProvider: () => fixedNow,
      );

      expect(cubit.state.status, RecipeDetailStatus.initial);
      expect(cubit.state.recipe, isNull);
      expect(cubit.state.match, isNull);
    });

    blocTest<RecipeDetailCubit, RecipeDetailState>(
      'loads recipe successfully and maps ingredients against user pantry',
      build: () {
        when(() => mockRecipeRepo.getRecipeById('52772')).thenAnswer(
          (_) async => const RecipeDetailResult(
            recipe: testRecipe,
            isStale: false,
          ),
        );
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => testPantry);
        return RecipeDetailCubit(
          recipeRepository: mockRecipeRepo,
          pantryRepository: mockPantryRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (cubit) => cubit.loadRecipe('52772'),
      expect: () => [
        isA<RecipeDetailState>().having(
            (s) => s.status, 'status', RecipeDetailStatus.loading),
        isA<RecipeDetailState>()
            .having((s) => s.status, 'status', RecipeDetailStatus.success)
            .having((s) => s.recipe?.id, 'recipe id', '52772')
            .having((s) => s.recipe?.name, 'recipe name',
                'Teriyaki Chicken Casserole')
            .having((s) => s.match, 'match', isNotNull)
            // Chicken and Soy Sauce are in pantry; Brown Rice is missing
            .having((s) => s.match?.matchedIngredients.length, 'matched count', 2)
            .having((s) => s.match?.missingIngredients.length, 'missing count', 1)
            .having((s) => s.match?.missingIngredients.first.name,
                'missing name', 'Brown Rice')
            .having((s) => s.isStale, 'isStale', isFalse),
      ],
    );

    blocTest<RecipeDetailCubit, RecipeDetailState>(
      'emits failure when recipe is not found',
      build: () {
        when(() => mockRecipeRepo.getRecipeById('99999')).thenAnswer(
          (_) async => const RecipeDetailResult(recipe: null),
        );
        return RecipeDetailCubit(
          recipeRepository: mockRecipeRepo,
          pantryRepository: mockPantryRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (cubit) => cubit.loadRecipe('99999'),
      expect: () => [
        isA<RecipeDetailState>().having(
            (s) => s.status, 'status', RecipeDetailStatus.loading),
        isA<RecipeDetailState>()
            .having((s) => s.status, 'status', RecipeDetailStatus.failure)
            .having((s) => s.errorMessage, 'error message',
                contains('Recipe not found')),
      ],
    );

    blocTest<RecipeDetailCubit, RecipeDetailState>(
      'emits failure when repository throws exception',
      build: () {
        when(() => mockRecipeRepo.getRecipeById(any())).thenThrow(
          Exception('Connection closed by peer'),
        );
        return RecipeDetailCubit(
          recipeRepository: mockRecipeRepo,
          pantryRepository: mockPantryRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (cubit) => cubit.loadRecipe('52772'),
      expect: () => [
        isA<RecipeDetailState>().having(
            (s) => s.status, 'status', RecipeDetailStatus.loading),
        isA<RecipeDetailState>()
            .having((s) => s.status, 'status', RecipeDetailStatus.failure)
            .having((s) => s.errorMessage, 'error message',
                contains('Connection closed')),
      ],
    );
  });
}

