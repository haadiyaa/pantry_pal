import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:pantry_pal/features/recipes/presentation/bloc/recipe_suggestions_bloc.dart';
import 'package:pantry_pal/features/recipes/presentation/bloc/recipe_suggestions_event.dart';
import 'package:pantry_pal/features/recipes/presentation/bloc/recipe_suggestions_state.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  late MockPantryRepository mockPantryRepo;
  late MockRecipeRepository mockRecipeRepo;
  final fixedNow = DateTime(2026, 10, 30, 10, 0);

  final samplePantry = [
    PantryItem(
      id: 1,
      name: 'Chicken Breast',
      quantity: 1,
      category: 'Meat and Fish',
      expiryDate: fixedNow.add(const Duration(days: 1)), // Expiring soon!
      addedAt: fixedNow,
    ),
    PantryItem(
      id: 2,
      name: 'Rice',
      quantity: 2,
      category: 'Grains',
      expiryDate: fixedNow.add(const Duration(days: 90)),
      addedAt: fixedNow,
    ),
  ];

  const recipeChicken = Recipe(
    id: '1',
    name: 'Teriyaki Chicken Rice',
    category: 'Chicken',
    area: 'Japanese',
    instructions: 'Cook chicken and rice.',
    ingredients: [
      RecipeIngredient(name: 'Chicken', measure: '200g'),
      RecipeIngredient(name: 'Rice', measure: '1 cup'),
      RecipeIngredient(name: 'Salt', measure: '1 tsp'),
    ],
  );

  const recipeVeg = Recipe(
    id: '2',
    name: 'Vegetable Fried Rice',
    category: 'Vegetarian',
    area: 'Chinese',
    instructions: 'Fry rice with peas and carrots.',
    ingredients: [
      RecipeIngredient(name: 'Rice', measure: '1 cup'),
      RecipeIngredient(name: 'Peas', measure: '1/2 cup'),
      RecipeIngredient(name: 'Carrot', measure: '1'),
    ],
  );

  setUp(() {
    mockPantryRepo = MockPantryRepository();
    mockRecipeRepo = MockRecipeRepository();
  });

  group('RecipeSuggestionsBloc', () {
    test('initial state has initial status and empty lists', () {
      final bloc = RecipeSuggestionsBloc(
        pantryRepository: mockPantryRepo,
        recipeRepository: mockRecipeRepo,
        nowProvider: () => fixedNow,
      );

      expect(bloc.state.status, RecipeSuggestionsStatus.initial);
      expect(bloc.state.allMatches, isEmpty);
      expect(bloc.state.filteredMatches, isEmpty);
      expect(bloc.state.isVegetarianOnly, isFalse);
      expect(bloc.state.isExpiringOnly, isFalse);
    });

    blocTest<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      'emits [loading, emptyPantry] when user pantry has 0 active items',
      build: () {
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => []);
        return RecipeSuggestionsBloc(
          pantryRepository: mockPantryRepo,
          recipeRepository: mockRecipeRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (bloc) => bloc.add(const RecipeSuggestionsStarted()),
      expect: () => [
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.loading),
        isA<RecipeSuggestionsState>()
            .having((s) => s.status, 'status', RecipeSuggestionsStatus.emptyPantry)
            .having((s) => s.allMatches, 'allMatches', isEmpty),
      ],
      verify: (_) {
        verifyNever(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: any(named: 'forceRefresh'),
            ));
      },
    );

    blocTest<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      'emits [loading, success] with ranked matches on successful fetch',
      build: () {
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => samplePantry);
        when(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: false,
            )).thenAnswer(
          (_) async => const RecipeQueryResult(
            recipes: [recipeChicken, recipeVeg],
            isStale: false,
            isPartial: false,
          ),
        );
        return RecipeSuggestionsBloc(
          pantryRepository: mockPantryRepo,
          recipeRepository: mockRecipeRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (bloc) => bloc.add(const RecipeSuggestionsStarted()),
      expect: () => [
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.loading),
        isA<RecipeSuggestionsState>()
            .having((s) => s.status, 'status', RecipeSuggestionsStatus.success)
            .having((s) => s.allMatches.length, 'allMatches length', 2)
            .having((s) => s.filteredMatches.length, 'filteredMatches length', 2)
            // Recipe Chicken consumes expiring chicken -> ranks first
            .having((s) => s.filteredMatches.first.recipe.id, 'first id', '1')
            .having((s) => s.isStale, 'isStale', isFalse)
            .having((s) => s.isPartial, 'isPartial', isFalse),
      ],
    );

    blocTest<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      'emits [loading, success] with isStale=true when offline cache is served',
      build: () {
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => samplePantry);
        when(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: false,
            )).thenAnswer(
          (_) async => const RecipeQueryResult(
            recipes: [recipeChicken],
            isStale: true,
            isPartial: false,
          ),
        );
        return RecipeSuggestionsBloc(
          pantryRepository: mockPantryRepo,
          recipeRepository: mockRecipeRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (bloc) => bloc.add(const RecipeSuggestionsStarted()),
      expect: () => [
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.loading),
        isA<RecipeSuggestionsState>()
            .having((s) => s.status, 'status', RecipeSuggestionsStatus.success)
            .having((s) => s.isStale, 'isStale', isTrue),
      ],
    );

    blocTest<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      'emits [loading, failure] when network fails without cache',
      build: () {
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => samplePantry);
        when(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: false,
            )).thenThrow(Exception('Network unreachable and no cache.'));
        return RecipeSuggestionsBloc(
          pantryRepository: mockPantryRepo,
          recipeRepository: mockRecipeRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (bloc) => bloc.add(const RecipeSuggestionsStarted()),
      expect: () => [
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.loading),
        isA<RecipeSuggestionsState>()
            .having((s) => s.status, 'status', RecipeSuggestionsStatus.failure)
            .having((s) => s.errorMessage, 'error message',
                contains('Network unreachable')),
      ],
    );

    blocTest<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      'emits [loading, success] with isPartial=true on partial ingredient results',
      build: () {
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => samplePantry);
        when(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: false,
            )).thenAnswer(
          (_) async => const RecipeQueryResult(
            recipes: [recipeChicken],
            isStale: false,
            isPartial: true,
            failedIngredients: ['rice'],
          ),
        );
        return RecipeSuggestionsBloc(
          pantryRepository: mockPantryRepo,
          recipeRepository: mockRecipeRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (bloc) => bloc.add(const RecipeSuggestionsStarted()),
      expect: () => [
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.loading),
        isA<RecipeSuggestionsState>()
            .having((s) => s.status, 'status', RecipeSuggestionsStatus.success)
            .having((s) => s.isPartial, 'isPartial', isTrue),
      ],
    );

    blocTest<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      'filtering by vegetarian, expiring only, and min match percentage updates filteredMatches without network calls',
      build: () {
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => samplePantry);
        when(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: false,
            )).thenAnswer(
          (_) async => const RecipeQueryResult(
            recipes: [recipeChicken, recipeVeg],
            isStale: false,
            isPartial: false,
          ),
        );
        return RecipeSuggestionsBloc(
          pantryRepository: mockPantryRepo,
          recipeRepository: mockRecipeRepo,
          nowProvider: () => fixedNow,
        );
      },
      seed: () => const RecipeSuggestionsState(),
      act: (bloc) async {
        bloc.add(const RecipeSuggestionsStarted());
        await Future.delayed(const Duration(milliseconds: 50));
        // Toggle Vegetarian: recipeChicken filtered out, only recipeVeg remains
        bloc.add(const RecipeSuggestionsVegetarianToggled());
        await Future.delayed(const Duration(milliseconds: 50));
        // Toggle Vegetarian back off
        bloc.add(const RecipeSuggestionsVegetarianToggled());
        await Future.delayed(const Duration(milliseconds: 50));
        // Toggle Expiring only: only recipeChicken remains (uses expiring chicken)
        bloc.add(const RecipeSuggestionsExpiringOnlyToggled());
        await Future.delayed(const Duration(milliseconds: 50));
        // Set Min Match to 75%+: recipeChicken (100%) remains, recipeVeg (33%) excluded
        bloc.add(const RecipeSuggestionsExpiringOnlyToggled());
        bloc.add(const RecipeSuggestionsMinMatchChanged(0.75));
      },
      expect: () => [
        // 1. Loading
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.loading),
        // 2. Success with 2 matches
        isA<RecipeSuggestionsState>()
            .having((s) => s.status, 'status', RecipeSuggestionsStatus.success)
            .having((s) => s.filteredMatches.length, 'filteredMatches length', 2),
        // 3. Vegetarian toggled ON -> 1 match (recipeVeg)
        isA<RecipeSuggestionsState>()
            .having((s) => s.isVegetarianOnly, 'isVegetarianOnly', isTrue)
            .having((s) => s.filteredMatches.length, 'filteredMatches length', 1)
            .having((s) => s.filteredMatches.first.recipe.name, 'veg name',
                'Vegetable Fried Rice'),
        // 4. Vegetarian toggled OFF -> 2 matches
        isA<RecipeSuggestionsState>()
            .having((s) => s.isVegetarianOnly, 'isVegetarianOnly', isFalse)
            .having((s) => s.filteredMatches.length, 'filteredMatches length', 2),
        // 5. Expiring only toggled ON -> 1 match (recipeChicken)
        isA<RecipeSuggestionsState>()
            .having((s) => s.isExpiringOnly, 'isExpiringOnly', isTrue)
            .having((s) => s.filteredMatches.length, 'filteredMatches length', 1)
            .having((s) => s.filteredMatches.first.recipe.name, 'name',
                'Teriyaki Chicken Rice'),
        // 6. Expiring toggled OFF
        isA<RecipeSuggestionsState>()
            .having((s) => s.isExpiringOnly, 'isExpiringOnly', isFalse)
            .having((s) => s.filteredMatches.length, 'filteredMatches length', 2),
        // 7. Min match 75% -> 1 match (recipeChicken at 100%)
        isA<RecipeSuggestionsState>()
            .having((s) => s.minMatchPercentage, 'minMatchPercentage', 0.75)
            .having((s) => s.filteredMatches.length, 'filteredMatches length', 1),
      ],
      verify: (_) {
        // Recipe repository was only queried once on started
        verify(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: false,
            )).called(1);
      },
    );

    blocTest<RecipeSuggestionsBloc, RecipeSuggestionsState>(
      'refreshed event queries repository with forceRefresh=true',
      build: () {
        when(() => mockPantryRepo.getAll()).thenAnswer((_) async => samplePantry);
        when(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: true,
            )).thenAnswer(
          (_) async => const RecipeQueryResult(
            recipes: [recipeChicken],
            isStale: false,
          ),
        );
        return RecipeSuggestionsBloc(
          pantryRepository: mockPantryRepo,
          recipeRepository: mockRecipeRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (bloc) => bloc.add(const RecipeSuggestionsRefreshed()),
      expect: () => [
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.loading),
        isA<RecipeSuggestionsState>().having(
            (s) => s.status, 'status', RecipeSuggestionsStatus.success),
      ],
      verify: (_) {
        verify(() => mockRecipeRepo.getRecipeSuggestions(
              pantryItems: any(named: 'pantryItems'),
              forceRefresh: true,
            )).called(1);
      },
    );
  });
}

