import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:pantry_pal/features/inventory/presentation/pages/item_form_page.dart';

class MockInventoryBloc extends MockBloc<InventoryEvent, InventoryState>
    implements InventoryBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const InventoryStarted());
  });

  late MockInventoryBloc inventoryBloc;

  setUp(() {
    inventoryBloc = MockInventoryBloc();
    when(() => inventoryBloc.state).thenReturn(const InventoryState());
  });

  Widget buildTestableWidget({int? itemId, PantryItem? initialItem}) {
    return MaterialApp(
      home: BlocProvider<InventoryBloc>.value(
        value: inventoryBloc,
        child: ItemFormPage(itemId: itemId, initialItem: initialItem),
      ),
    );
  }

  group('ItemFormPage widget tests', () {
    testWidgets('shows validation error when saving with an empty name',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      // Tap the Save / Add Item button without entering any text
      final saveButton = find.byKey(const Key('save_item_button'));
      expect(saveButton, findsOneWidget);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Expect inline validation error to be rendered
      expect(find.text('Item name is required'), findsOneWidget);

      // Verify that no event was dispatched to the Bloc
      verifyNever(() => inventoryBloc.add(any()));
    });

    testWidgets('quantity stepper enforces minimum value of 1',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      // Initial quantity should be 1
      expect(find.text('1'), findsOneWidget);

      // Decrement button should be disabled when quantity is 1
      final decrementButton =
          tester.widget<IconButton>(find.byKey(const Key('quantity_decrement_button')));
      expect(decrementButton.onPressed, isNull);

      // Increment quantity to 2
      final incrementButton = find.byKey(const Key('quantity_increment_button'));
      await tester.tap(incrementButton);
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);

      // Now decrement button should be enabled
      final enabledDecrementButton =
          tester.widget<IconButton>(find.byKey(const Key('quantity_decrement_button')));
      expect(enabledDecrementButton.onPressed, isNotNull);

      // Decrement back to 1
      await tester.tap(find.byKey(const Key('quantity_decrement_button')));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('dispatches InventoryItemAdded when form is valid',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());

      // Fill in item name
      await tester.enterText(
        find.byKey(const Key('item_name_field')),
        'Organic Strawberries',
      );

      // Increment quantity
      await tester.tap(find.byKey(const Key('quantity_increment_button')));
      await tester.pumpAndSettle();

      // Save form
      await tester.tap(find.byKey(const Key('save_item_button')));
      await tester.pump();

      // Verify event was dispatched with correct name and quantity
      verify(
        () => inventoryBloc.add(
          any(
            that: isA<InventoryItemAdded>().having(
              (e) => e.item.name,
              'name',
              'Organic Strawberries',
            ).having(
              (e) => e.item.quantity,
              'quantity',
              2,
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets('pre-populates existing item and dispatches InventoryItemUpdated on edit',
        (tester) async {
      final existingItem = PantryItem(
        id: 7,
        name: 'Whole Milk',
        quantity: 3,
        category: 'Dairy',
        expiryDate: DateTime(2026, 8, 15),
        barcode: '987654321',
        addedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        buildTestableWidget(itemId: 7, initialItem: existingItem),
      );

      // Check pre-populated values
      expect(find.text('Whole Milk'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Edit Item'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Modify the name
      await tester.enterText(find.byKey(const Key('item_name_field')), 'Oat Milk');

      // Tap save
      await tester.tap(find.byKey(const Key('save_item_button')));
      await tester.pump();

      // Verify update event
      verify(
        () => inventoryBloc.add(
          any(
            that: isA<InventoryItemUpdated>().having(
              (e) => e.item.id,
              'id',
              7,
            ).having(
              (e) => e.item.name,
              'name',
              'Oat Milk',
            ).having(
              (e) => e.item.quantity,
              'quantity',
              3,
            ),
          ),
        ),
      ).called(1);
    });
  });
}
