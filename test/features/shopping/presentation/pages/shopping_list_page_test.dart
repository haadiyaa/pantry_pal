import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_item.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_source_type.dart';
import 'package:pantry_pal/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:pantry_pal/features/shopping/presentation/pages/shopping_list_page.dart';

class MockShoppingRepository extends Mock implements ShoppingRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

void main() {
  late MockShoppingRepository shoppingRepo;
  late MockPantryRepository pantryRepo;
  late StreamController<List<ShoppingItem>> streamController;

  final fixedDate = DateTime(2026, 6, 1);

  final sampleItem = ShoppingItem(
    id: 1,
    name: 'Almond Milk',
    normalizedName: 'almond milk',
    quantity: 1,
    category: 'Dairy',
    isBought: false,
    sourceType: ShoppingSourceType.manual,
    sourceLabel: 'Manual',
    addedAt: fixedDate,
  );

  final sampleBought = ShoppingItem(
    id: 2,
    name: 'Bananas',
    normalizedName: 'bananas',
    quantity: 6,
    category: 'Fruits',
    isBought: true,
    sourceType: ShoppingSourceType.recipe,
    sourceLabel: 'Banana Bread',
    addedAt: fixedDate,
    boughtAt: fixedDate,
  );

  setUpAll(() {
    registerFallbackValue(sampleItem);
  });

  setUp(() {
    shoppingRepo = MockShoppingRepository();
    pantryRepo = MockPantryRepository();
    streamController = StreamController<List<ShoppingItem>>.broadcast();

    when(() => shoppingRepo.watchAll())
        .thenAnswer((_) => streamController.stream);
    when(() => shoppingRepo.getAll()).thenAnswer((_) async => []);
    when(() => pantryRepo.getAll()).thenAnswer((_) async => <PantryItem>[]);
  });

  tearDown(() async {
    await streamController.close();
  });

  Widget buildWidget() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ShoppingRepository>.value(value: shoppingRepo),
        RepositoryProvider<PantryRepository>.value(value: pantryRepo),
      ],
      child: const MaterialApp(
        home: ShoppingListPage(),
      ),
    );
  }

  group('ShoppingListPage widget tests', () {
    testWidgets('renders empty state when list has no items', (tester) async {
      await tester.pumpWidget(buildWidget());
      streamController.add([]);
      await tester.pumpAndSettle();

      expect(find.text('Shopping List'), findsOneWidget);
      expect(find.text('Your shopping list is empty'), findsOneWidget);
      expect(find.byKey(const Key('shopping_quick_add_input')), findsOneWidget);
    });

    testWidgets('quick add bar submits new item to repository', (tester) async {
      when(() => shoppingRepo.add(any())).thenAnswer((_) async => 1);

      await tester.pumpWidget(buildWidget());
      streamController.add([]);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('shopping_quick_add_input')),
        'Greek Yogurt',
      );
      await tester.tap(find.byKey(const Key('shopping_quick_add_button')));
      await tester.pumpAndSettle();

      verify(
        () => shoppingRepo.add(
          any(
            that: isA<ShoppingItem>()
                .having((i) => i.name, 'name', 'Greek Yogurt'),
          ),
        ),
      ).called(1);
    });

    testWidgets('renders category header, unchecked item, source badge, and bought section',
        (tester) async {
      when(() => shoppingRepo.setBought(
            1,
            true,
            boughtAt: any(named: 'boughtAt'),
          )).thenAnswer((_) async => 1);

      await tester.pumpWidget(buildWidget());
      streamController.add([sampleItem, sampleBought]);
      await tester.pumpAndSettle();

      // Category headers
      expect(find.text('Dairy'), findsWidgets);

      // Unchecked item
      expect(find.text('Almond Milk'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);

      // Bought item
      expect(find.text('Bought (1)'), findsOneWidget);
      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Banana Bread'), findsOneWidget);

      // Add to pantry button
      expect(find.byKey(const Key('move_bought_to_pantry_button')), findsOneWidget);

      // Tap checkbox to mark bought
      final checkbox = find.byType(Checkbox).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      verify(() => shoppingRepo.setBought(1, true, boughtAt: any(named: 'boughtAt')))
          .called(1);
    });
  });
}
