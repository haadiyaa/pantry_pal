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

  const testRecipe = Recipe(
    id: '52772',
    name: 'Teriyaki Chicken Casserole',
    category: 'Chicken',
    area: 'Japanese',
    instructions: 'Combine ingredients and bake at 350 degrees.',
    imageUrl: null,
    youtubeUrl: 'https://www.youtube.com/watch?v=4aZr5hZXP_s',
    ingredients: [
      RecipeIngredient(name: 'Chicken Breasts', measure: '2'),
      RecipeIngredient(name: 'Soy Sauce', measure: '1/2 cup'),
      RecipeIngredient(name: 'Salt', measure: '1 tsp'),
    ],
  );

  setUp(() {
    mockRecipeRepo = MockRecipeRepository();
    mockPantryRepo = MockPantryRepository();
    fakeStaplesRepo = FakeStaplesRepository();
  });

  Widget buildTestableWidget() {
    return MaterialApp(
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RecipeRepository>.value(value: mockRecipeRepo),
          RepositoryProvider<PantryRepository>.value(value: mockPantryRepo),
          RepositoryProvider<StaplesRepository>.value(value: fakeStaplesRepo),
        ],
        child: const RecipeDetailPage(recipeId: '52772'),
      ),
    );
  }

  group('RecipeDetailPage widget tests', () {
    testWidgets('renders all three ingredient statuses with exact labels and icons',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      // User only has Chicken Breasts in pantry; Soy Sauce is missing; Salt is a staple
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
      expect(
          find.text('Combine ingredients and bake at 350 degrees.'), findsOneWidget);

      // Verify badges:
      // 1. In pantry (Chicken Breasts)
      expect(find.text('In pantry'), findsOneWidget);
      // 2. Staple (Salt) - Must NEVER be labelled "In pantry"
      expect(find.text('Usually in every kitchen'), findsOneWidget);
      expect(find.byIcon(Icons.kitchen_outlined), findsOneWidget);
      // 3. Missing (Soy Sauce)
      expect(find.text('Missing'), findsOneWidget);

      // Verify Live Summary in header
      expect(find.byKey(const Key('header_summary_text')), findsOneWidget);
      expect(find.text('You have 2 of 3 ingredients'), findsOneWidget);

      // Verify Add to pantry button exists for non-staple missing item (Soy Sauce)
      expect(find.byKey(const Key('add_to_pantry_Soy Sauce')), findsOneWidget);
      // Verify Add to pantry button does NOT exist for staple (Salt) or pantry item (Chicken)
      expect(find.byKey(const Key('add_to_pantry_Salt')), findsNothing);
      expect(find.byKey(const Key('add_to_pantry_Chicken Breasts')), findsNothing);

      // Verify Step 7 hook button exists and is enabled (live in Step 7)
      final step7Button = tester.widget<FilledButton>(
        find.byKey(const Key('add_missing_to_shopping_list_hook')),
      );
      expect(step7Button.onPressed, isNotNull);

      // Verify YouTube button
      expect(find.byKey(const Key('watch_youtube_video_button')), findsOneWidget);

      // Verify caption for temporary marks
      expect(
        find.text(
          'Marks applied here are temporary and apply only to this recipe. They will be reset when you leave this screen.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ticking "I have this" checkbox live-updates summary and shows mark badge',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
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

      expect(find.text('You have 2 of 3 ingredients'), findsOneWidget);

      // Tick the checkbox for Soy Sauce
      final soyCheckboxFinder = find.byKey(const Key('checkbox_Soy Sauce'));
      expect(soyCheckboxFinder, findsOneWidget);
      await tester.ensureVisible(soyCheckboxFinder);
      await tester.tap(soyCheckboxFinder);
      await tester.pumpAndSettle();

      // Now availableCount becomes 3 of 3, with "(includes your manual marks)" note
      expect(
        find.text(
            'You have 3 of 3 ingredients (includes your manual marks)'),
        findsOneWidget,
      );
      // Badge changes to "You marked: have it"
      expect(find.text('You marked: have it'), findsOneWidget);
      expect(find.text('Missing'), findsNothing);
    });

    testWidgets('unticking a staple globally marks it missing and drops count',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
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

      expect(find.text('Usually in every kitchen'), findsOneWidget);
      expect(find.text('You have 2 of 3 ingredients'), findsOneWidget);

      // Untick Salt
      final saltCheckboxFinder = find.byKey(const Key('checkbox_Salt'));
      expect(saltCheckboxFinder, findsOneWidget);
      await tester.ensureVisible(saltCheckboxFinder);
      await tester.tap(saltCheckboxFinder);
      await tester.pumpAndSettle();

      // Salt is now missing; availableCount drops to 1 of 3
      expect(find.text('You have 1 of 3 ingredients'), findsOneWidget);
      expect(fakeStaplesRepo.getUnavailableStaples(), completion(contains('salt')));
    });
  });
}
