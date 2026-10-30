import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe.dart';
import 'package:pantry_pal/features/recipes/domain/models/recipe_ingredient.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:pantry_pal/features/recipes/domain/repositories/staples_repository.dart';
import 'package:pantry_pal/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_item.dart';
import 'package:pantry_pal/features/shopping/domain/repositories/shopping_repository.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

class MockShoppingRepository extends Mock implements ShoppingRepository {}

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
  late MockRecipeRepository recipeRepo;
  late MockPantryRepository pantryRepo;
  late FakeStaplesRepository staplesRepo;
  late MockShoppingRepository shoppingRepo;

  final fixedDate = DateTime(2026, 6, 1);

  const testRecipe = Recipe(
    id: '52772',
    name: 'Teriyaki Chicken Casserole',
    category: 'Chicken',
    area: 'Japanese',
    instructions: 'Mix and bake.',
    ingredients: [
      RecipeIngredient(name: 'Chicken Breasts', measure: '2'),
      RecipeIngredient(name: 'Soy Sauce', measure: '1/2 cup'),
      RecipeIngredient(name: 'Salt', measure: '1 tsp'),
    ],
  );

  final chickenInPantry = PantryItem(
    id: 1,
    name: 'Chicken Breasts',
    quantity: 2,
    category: 'Meat and Fish',
    expiryDate: fixedDate.add(const Duration(days: 3)),
    addedAt: fixedDate,
  );

  setUpAll(() {
    registerFallbackValue(<ShoppingItem>[]);
  });

  setUp(() {
    recipeRepo = MockRecipeRepository();
    pantryRepo = MockPantryRepository();
    staplesRepo = FakeStaplesRepository();
    shoppingRepo = MockShoppingRepository();

    when(() => recipeRepo.getRecipeById('52772')).thenAnswer(
      (_) async => const RecipeDetailResult(
        recipe: testRecipe,
        isStale: false,
      ),
    );

    when(() => pantryRepo.getAll())
        .thenAnswer((_) async => [chickenInPantry]);

    when(() => shoppingRepo.addAll(any())).thenAnswer((_) async => [1]);
  });

  Widget buildWidget() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RecipeRepository>.value(value: recipeRepo),
        RepositoryProvider<PantryRepository>.value(value: pantryRepo),
        RepositoryProvider<StaplesRepository>.value(value: staplesRepo),
        RepositoryProvider<ShoppingRepository>.value(value: shoppingRepo),
      ],
      child: const MaterialApp(
        home: RecipeDetailPage(recipeId: '52772'),
      ),
    );
  }

  testWidgets(
      'Tapping "Add missing ingredients to shopping list" adds missing items to shopping repository and shows snackbar',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    // Scroll to find the shopping hook button
    final hookFinder =
        find.byKey(const Key('add_missing_to_shopping_list_hook'));
    await tester.scrollUntilVisible(
      hookFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(hookFinder, findsOneWidget);

    // Tap the button
    await tester.tap(hookFinder);
    await tester.pumpAndSettle();

    // Verify shoppingRepo.addAll was called with 'Soy Sauce'
    verify(
      () => shoppingRepo.addAll(
        any(
          that: isA<List<ShoppingItem>>().having(
            (items) => items.first.name,
            'name',
            'Soy Sauce',
          ).having(
            (items) => items.first.sourceLabel,
            'sourceLabel',
            'Teriyaki Chicken Casserole',
          ),
        ),
      ),
    ).called(1);

    // Verify SnackBar with View list action
    expect(find.text('Added 1 item to shopping list'), findsOneWidget);
    expect(find.text('View list'), findsOneWidget);
  });
}
