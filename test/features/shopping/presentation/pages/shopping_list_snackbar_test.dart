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

  final itemA = ShoppingItem(
    id: 1,
    name: 'Almond Milk',
    normalizedName: 'almond milk',
    quantity: 1,
    category: 'Dairy',
    isBought: false,
    sourceType: ShoppingSourceType.manual,
    addedAt: fixedDate,
  );

  final itemB = ShoppingItem(
    id: 2,
    name: 'Oatmeal',
    normalizedName: 'oatmeal',
    quantity: 1,
    category: 'Grains',
    isBought: false,
    sourceType: ShoppingSourceType.manual,
    addedAt: fixedDate,
  );

  final boughtItem1 = ShoppingItem(
    id: 10,
    name: 'Apples',
    normalizedName: 'apples',
    quantity: 3,
    category: 'Fruits',
    isBought: true,
    sourceType: ShoppingSourceType.manual,
    addedAt: fixedDate,
    boughtAt: fixedDate,
  );

  final boughtItem2 = ShoppingItem(
    id: 11,
    name: 'Bread',
    normalizedName: 'bread',
    quantity: 1,
    category: 'Bakery',
    isBought: true,
    sourceType: ShoppingSourceType.manual,
    addedAt: fixedDate,
    boughtAt: fixedDate,
  );

  setUpAll(() {
    registerFallbackValue(itemA);
    registerFallbackValue(
      PantryItem(
        name: 'test',
        quantity: 1,
        category: 'Other',
        expiryDate: fixedDate,
        addedAt: fixedDate,
      ),
    );
  });

  setUp(() {
    shoppingRepo = MockShoppingRepository();
    pantryRepo = MockPantryRepository();
    streamController = StreamController<List<ShoppingItem>>.broadcast();

    when(() => shoppingRepo.watchAll()).thenAnswer((_) => streamController.stream);
    when(() => shoppingRepo.delete(any())).thenAnswer((_) async {});
    when(() => shoppingRepo.restore(any())).thenAnswer((_) async => 1);
    when(() => shoppingRepo.clearBought()).thenAnswer((_) async => [boughtItem1, boughtItem2]);
    when(() => pantryRepo.search(query: any(named: 'query'))).thenAnswer((_) async => []);
  });

  tearDown(() {
    streamController.close();
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

  group('ShoppingListPage SnackBar and Undo lifecycle', () {
    testWidgets('Swipe to delete item shows floating snackbar with correct text and Undo button', (tester) async {
      await tester.pumpWidget(buildWidget());
      streamController.add([itemA]);
      await tester.pumpAndSettle();

      expect(find.text('Almond Milk'), findsOneWidget);

      // Swipe to delete
      await tester.drag(find.text('Almond Milk'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Deleted "Almond Milk"'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Verify top banner style
      expect(find.byKey(const Key('app_top_banner')), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      verify(() => shoppingRepo.restore(itemA)).called(1);
    });

    testWidgets('Rapid delete: swipe A then swipe B clears A immediately and undo restores only B', (tester) async {
      await tester.pumpWidget(buildWidget());
      streamController.add([itemA, itemB]);
      await tester.pumpAndSettle();

      // Swipe item A
      await tester.drag(find.text('Almond Milk'), const Offset(-500, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Deleted "Almond Milk"'), findsOneWidget);

      // Rapidly swipe item B
      await tester.drag(find.text('Oatmeal'), const Offset(-500, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      // First is gone, second is shown
      expect(find.text('Deleted "Almond Milk"'), findsNothing);
      expect(find.text('Deleted "Oatmeal"'), findsOneWidget);
      expect(find.byKey(const Key('app_top_banner')), findsOneWidget);

      // Undo restores ONLY Oatmeal
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      verify(() => shoppingRepo.restore(itemB)).called(1);
      verifyNever(() => shoppingRepo.restore(itemA));
    });

    testWidgets('Clear bought items shows correct item count and Undo restores all cleared items', (tester) async {
      await tester.pumpWidget(buildWidget());
      streamController.add([boughtItem1, boughtItem2]);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Clear bought items'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear bought items'));
      await tester.pumpAndSettle();

      expect(find.text('Cleared 2 bought items'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      verify(() => shoppingRepo.restore(boughtItem1)).called(1);
      verify(() => shoppingRepo.restore(boughtItem2)).called(1);
    });

    testWidgets('Quick add bar shows validation snackbar on empty submission', (tester) async {
      await tester.pumpWidget(buildWidget());
      streamController.add([]);
      await tester.pumpAndSettle();

      // Tap Add button without entering text
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('Please enter an item name to add to the shopping list'), findsOneWidget);
      expect(find.byKey(const Key('app_top_banner')), findsOneWidget);
    });
  });
}
