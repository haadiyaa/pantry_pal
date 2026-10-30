import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:pantry_pal/features/recipes/presentation/pages/recipe_detail_page.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

void main() {
  late MockRecipeRepository mockRecipeRepo;
  late MockPantryRepository mockPantryRepo;

  const testRecipe = Recipe(
    id: '52772',
    name: 'Teriyaki Chicken Casserole',
    category: 'Chicken',
    area: 'Japanese',
    instructions: 'Combine ingredients and bake at 350 degrees.',
    imageUrl: null,
    youtubeUrl: 'https://www.youtube.com/watch?v=4aZr5hZXP_s',
    ingredients: [
      RecipeIngredient(name: 'Chicken', measure: '2 breasts'),
      RecipeIngredient(name: 'Soy Sauce', measure: '1/2 cup'),
    ],
  );

  setUp(() {
    mockRecipeRepo = MockRecipeRepository();
    mockPantryRepo = MockPantryRepository();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RecipeRepository>.value(value: mockRecipeRepo),
          RepositoryProvider<PantryRepository>.value(value: mockPantryRepo),
        ],
        child: const RecipeDetailPage(recipeId: '52772'),
      ),
    );
  }

  group('RecipeDetailPage widget tests', () {
    testWidgets('renders ingredient list marking items In Pantry vs Missing',
        (tester) async {
      // User only has Chicken in pantry; Soy Sauce is missing
      when(() => mockPantryRepo.getAll()).thenAnswer((_) async => [
            PantryItem(
              id: 1,
              name: 'Chicken Breast',
              quantity: 2,
              category: 'Meat and Fish',
              expiryDate: DateTime.now().add(const Duration(days: 5)),
              addedAt: DateTime.now(),
            ),
          ]);
      when(() => mockRecipeRepo.getRecipeById('52772')).thenAnswer(
        (_) async => const RecipeDetailResult(
          recipe: testRecipe,
          isStale: false,
        ),
      );

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Check title and instructions
      expect(find.text('Teriyaki Chicken Casserole'), findsOneWidget);
      expect(find.text('Combine ingredients and bake at 350 degrees.'), findsOneWidget);

      // Check ingredients tiles
      expect(find.byKey(const Key('ingredient_tile_Chicken')), findsOneWidget);
      expect(find.byKey(const Key('ingredient_tile_Soy Sauce')), findsOneWidget);

      // Verify badges: 1 In pantry, 1 Missing
      expect(find.text('In pantry'), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);

      // Verify Step 7 hook button exists and is disabled
      final step7Button = tester.widget<FilledButton>(
        find.byKey(const Key('add_missing_to_shopping_list_hook')),
      );
      expect(step7Button.onPressed, isNull);

      // Verify YouTube button
      expect(find.byKey(const Key('watch_youtube_video_button')), findsOneWidget);
    });
  });
}

