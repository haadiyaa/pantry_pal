import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient_status.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/staples_repository.dart';
import 'package:pantry_pal/features/recipes/presentation/cubit/recipe_detail_cubit.dart';
import 'package:pantry_pal/features/recipes/presentation/cubit/recipe_detail_state.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

class FakeStaplesRepository implements StaplesRepository {
  FakeStaplesRepository([Set<String>? initial])
      : _unavailable = initial != null ? Set.from(initial) : <String>{};

  final Set<String> _unavailable;

  @override
  Future<Set<String>> getUnavailableStaples() async => Set.from(_unavailable);

  @override
  Future<void> setStapleAvailability(
      String stapleKeyword, bool isAvailable) async {
    if (isAvailable) {
      _unavailable.remove(stapleKeyword);
    } else {
      _unavailable.add(stapleKeyword);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockRecipeRepository mockRecipeRepo;
  late MockPantryRepository mockPantryRepo;
  late FakeStaplesRepository fakeStaplesRepo;
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
      RecipeIngredient(name: 'Salt', measure: '1 tsp'),
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
    fakeStaplesRepo = FakeStaplesRepository();
  });

  group('RecipeDetailCubit', () {
    test('initial state has initial status and null recipe', () {
      final cubit = RecipeDetailCubit(
        recipeRepository: mockRecipeRepo,
        pantryRepository: mockPantryRepo,
        staplesRepository: fakeStaplesRepo,
        nowProvider: () => fixedNow,
      );

      expect(cubit.state.status, RecipeDetailStatus.initial);
      expect(cubit.state.recipe, isNull);
      expect(cubit.state.match, isNull);
      expect(cubit.state.detailMatch, isNull);
      expect(cubit.state.userMarkedAvailable, isEmpty);
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
          staplesRepository: fakeStaplesRepo,
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
            // Real pantry matches: Chicken and Soy Sauce (2)
            .having((s) => s.match?.matchedIngredients.length, 'matched count', 2)
            // Missing: Brown Rice (1)
            .having((s) => s.match?.missingIngredients.length, 'missing count', 1)
            // Staple: Salt (1, assumed available, never counted as in-pantry)
            .having((s) => s.match?.stapleIngredients.length, 'staple count', 1)
            .having((s) => s.detailMatch?.inPantryCount, 'detail in pantry', 2)
            .having((s) => s.detailMatch?.stapleCount, 'detail staples', 1)
            .having((s) => s.detailMatch?.missingCount, 'detail missing', 1)
            .having((s) => s.isStale, 'isStale', isFalse),
      ],
    );

    test('toggleUserMark toggles ephemeral marks and updates live summary',
        () async {
      when(() => mockRecipeRepo.getRecipeById('52772')).thenAnswer(
        (_) async => const RecipeDetailResult(
          recipe: testRecipe,
          isStale: false,
        ),
      );
      when(() => mockPantryRepo.getAll()).thenAnswer((_) async => testPantry);

      final cubit = RecipeDetailCubit(
        recipeRepository: mockRecipeRepo,
        pantryRepository: mockPantryRepo,
        staplesRepository: fakeStaplesRepo,
        nowProvider: () => fixedNow,
      );

      await cubit.loadRecipe('52772');
      expect(cubit.state.detailMatch?.availableCount, 3); // 2 in pantry + 1 staple
      expect(cubit.state.detailMatch?.hasManualMarks, isFalse);

      // User ticks "Brown Rice" ("I have this")
      cubit.toggleUserMark('Brown Rice');
      expect(cubit.state.userMarkedAvailable.contains('rice'), isTrue);
      expect(cubit.state.detailMatch?.availableCount, 4); // 2 pantry + 1 staple + 1 user mark
      expect(cubit.state.detailMatch?.hasManualMarks, isTrue);
      expect(
        cubit.state.detailMatch?.summaryText,
        contains('includes your manual marks'),
      );

      // Untick "Brown Rice"
      cubit.toggleUserMark('Brown Rice');
      expect(cubit.state.userMarkedAvailable.contains('rice'), isFalse);
      expect(cubit.state.detailMatch?.availableCount, 3);
      expect(cubit.state.detailMatch?.hasManualMarks, isFalse);
    });

    test('toggleStapleAvailability persists override and toggles staple status',
        () async {
      when(() => mockRecipeRepo.getRecipeById('52772')).thenAnswer(
        (_) async => const RecipeDetailResult(
          recipe: testRecipe,
          isStale: false,
        ),
      );
      when(() => mockPantryRepo.getAll()).thenAnswer((_) async => testPantry);

      final cubit = RecipeDetailCubit(
        recipeRepository: mockRecipeRepo,
        pantryRepository: mockPantryRepo,
        staplesRepository: fakeStaplesRepo,
        nowProvider: () => fixedNow,
      );

      await cubit.loadRecipe('52772');
      final saltItemBefore = cubit.state.detailMatch?.items
          .firstWhere((i) => i.ingredient.name == 'Salt');
      expect(saltItemBefore?.status, RecipeIngredientStatus.staple);
      expect(saltItemBefore?.isStapleAvailable, isTrue);

      // Untick Salt (out of salt in kitchen)
      await cubit.toggleStapleAvailability('Salt');
      final unavail = await fakeStaplesRepo.getUnavailableStaples();
      expect(unavail.contains('salt'), isTrue);

      final saltItemAfter = cubit.state.detailMatch?.items
          .firstWhere((i) => i.ingredient.name == 'Salt');
      expect(saltItemAfter?.isStapleAvailable, isFalse);
      expect(saltItemAfter?.isMissing, isTrue);

      // Retick Salt (bought salt)
      await cubit.toggleStapleAvailability('Salt');
      final unavail2 = await fakeStaplesRepo.getUnavailableStaples();
      expect(unavail2.contains('salt'), isFalse);
    });

    blocTest<RecipeDetailCubit, RecipeDetailState>(
      'emits failure when recipe is not found',
      build: () {
        when(() => mockRecipeRepo.getRecipeById('99999')).thenAnswer(
          (_) async => const RecipeDetailResult(recipe: null),
        );
        return RecipeDetailCubit(
          recipeRepository: mockRecipeRepo,
          pantryRepository: mockPantryRepo,
          staplesRepository: fakeStaplesRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (cubit) => cubit.loadRecipe('99999'),
      expect: () => [
        isA<RecipeDetailState>().having(
            (s) => s.status, 'status', RecipeDetailStatus.loading),
        isA<RecipeDetailState>()
            .having((s) => s.status, 'status', RecipeDetailStatus.failure)
            .having((s) => s.errorMessage, 'error message', 'Recipe not found.'),
      ],
    );

    blocTest<RecipeDetailCubit, RecipeDetailState>(
      'emits failure when repository throws exception',
      build: () {
        when(() => mockRecipeRepo.getRecipeById('52772')).thenThrow(
          Exception('Network failure'),
        );
        return RecipeDetailCubit(
          recipeRepository: mockRecipeRepo,
          pantryRepository: mockPantryRepo,
          staplesRepository: fakeStaplesRepo,
          nowProvider: () => fixedNow,
        );
      },
      act: (cubit) => cubit.loadRecipe('52772'),
      expect: () => [
        isA<RecipeDetailState>().having(
            (s) => s.status, 'status', RecipeDetailStatus.loading),
        isA<RecipeDetailState>()
            .having((s) => s.status, 'status', RecipeDetailStatus.failure)
            .having((s) => s.errorMessage, 'error message', 'Network failure'),
      ],
    );
  });
}
