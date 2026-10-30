import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:pantry_pal/features/recipes/presentation/pages/recipes_page.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockInventoryBloc extends MockBloc<InventoryEvent, InventoryState>
    implements InventoryBloc {}

void main() {
  late MockPantryRepository mockPantryRepo;
  late MockRecipeRepository mockRecipeRepo;
  late MockInventoryBloc mockInventoryBloc;

  const testRecipe = Recipe(
    id: '52772',
    name: 'Teriyaki Chicken Casserole',
    category: 'Chicken',
    area: 'Japanese',
    instructions: 'Bake casserole.',
    imageUrl: null,
    ingredients: [
      RecipeIngredient(name: 'Chicken', measure: '2'),
      RecipeIngredient(name: 'Rice', measure: '1 cup'),
    ],
  );

  setUp(() {
    mockPantryRepo = MockPantryRepository();
    mockRecipeRepo = MockRecipeRepository();
    mockInventoryBloc = MockInventoryBloc();
    when(() => mockInventoryBloc.state).thenReturn(const InventoryState());
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<PantryRepository>.value(value: mockPantryRepo),
          RepositoryProvider<RecipeRepository>.value(value: mockRecipeRepo),
        ],
        child: BlocProvider<InventoryBloc>.value(
          value: mockInventoryBloc,
          child: const RecipesPage(),
        ),
      ),
    );
  }

  group('RecipesPage widget tests', () {
    testWidgets('displays empty pantry view when pantry has no active items',
        (tester) async {
      when(() => mockPantryRepo.getAll()).thenAnswer((_) async => []);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Your pantry is empty'), findsOneWidget);
      expect(find.text('Add Pantry Items'), findsOneWidget);
    });

    testWidgets('displays error state with retry button when repository fails',
        (tester) async {
      when(() => mockPantryRepo.getAll()).thenAnswer((_) async => [
            PantryItem(
              id: 1,
              name: 'Chicken',
              quantity: 1,
              category: 'Meat and Fish',
              expiryDate: DateTime(2026, 11, 10),
              addedAt: DateTime(2026, 10, 30),
            ),
          ]);
      when(() => mockRecipeRepo.getRecipeSuggestions(
            pantryItems: any(named: 'pantryItems'),
            forceRefresh: any(named: 'forceRefresh'),
          )).thenThrow(Exception('Failed to load'));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load recipes'), findsOneWidget);
      expect(find.byKey(const Key('retry_recipes_button')), findsOneWidget);
    });

    testWidgets('displays recipe results cards when recipes are matched',
        (tester) async {
      when(() => mockPantryRepo.getAll()).thenAnswer((_) async => [
            PantryItem(
              id: 1,
              name: 'Chicken',
              quantity: 1,
              category: 'Meat and Fish',
              expiryDate: DateTime.now().add(const Duration(days: 1)),
              addedAt: DateTime.now(),
            ),
            PantryItem(
              id: 2,
              name: 'Rice',
              quantity: 2,
              category: 'Grains',
              expiryDate: DateTime.now().add(const Duration(days: 60)),
              addedAt: DateTime.now(),
            ),
          ]);
      when(() => mockRecipeRepo.getRecipeSuggestions(
            pantryItems: any(named: 'pantryItems'),
            forceRefresh: any(named: 'forceRefresh'),
          )).thenAnswer(
        (_) async => const RecipeQueryResult(
          recipes: [testRecipe],
          isStale: false,
          isPartial: false,
        ),
      );

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Teriyaki Chicken Casserole'), findsOneWidget);
      expect(find.text('100% Match'), findsOneWidget);
      expect(find.text('Japanese'), findsOneWidget);
      expect(find.text('Chicken'), findsOneWidget);
      expect(find.byKey(const Key('recipe_card_52772')), findsOneWidget);
    });
  });
}

