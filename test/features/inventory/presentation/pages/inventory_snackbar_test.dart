import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/core/ui/ui_message.dart';
import 'package:pantry_pal/features/inventory/domain/models/consume_result.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event_reason.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:pantry_pal/features/inventory/presentation/pages/inventory_page.dart';
import 'package:pantry_pal/features/shopping/presentation/cubit/shopping_badge_cubit.dart';

class MockInventoryBloc extends MockBloc<InventoryEvent, InventoryState>
    implements InventoryBloc {}

class MockShoppingBadgeCubit extends MockCubit<int>
    implements ShoppingBadgeCubit {}

void main() {
  setUpAll(() {
    registerFallbackValue(const InventoryStarted());
  });

  late MockInventoryBloc inventoryBloc;
  late MockShoppingBadgeCubit badgeCubit;
  late StreamController<InventoryState> stateController;

  final itemA = PantryItem(
    id: 1,
    name: 'Apple',
    quantity: 1,
    category: 'Produce',
    expiryDate: DateTime(2026, 12, 1),
    addedAt: DateTime(2026, 1, 1),
  );

  final itemB = PantryItem(
    id: 2,
    name: 'Banana',
    quantity: 1,
    category: 'Produce',
    expiryDate: DateTime(2026, 12, 1),
    addedAt: DateTime(2026, 1, 1),
  );

  ConsumeResult makeResult(PantryItem item, PantryEventReason reason, {int? shoppingId}) {
    return ConsumeResult(
      item: item,
      event: PantryEvent(
        itemName: item.name,
        category: item.category,
        quantity: 1,
        pricePaise: null,
        expiryDate: item.expiryDate,
        reason: reason,
        occurredAt: DateTime.now(),
      ),
      wasRemoved: true,
      previousQuantity: item.quantity,
      shoppingItemId: shoppingId,
      shoppingItemQuantityAdded: shoppingId != null ? 1 : 0,
      shoppingItemWasCreated: false,
    );
  }

  setUp(() {
    inventoryBloc = MockInventoryBloc();
    badgeCubit = MockShoppingBadgeCubit();
    stateController = StreamController<InventoryState>.broadcast();

    when(() => badgeCubit.state).thenReturn(0);
    when(() => badgeCubit.stream).thenAnswer((_) => const Stream.empty());

    when(() => inventoryBloc.state).thenReturn(
      InventoryState(
        status: InventoryStatus.success,
        items: [itemA, itemB],
        totalItemCount: 2,
      ),
    );
    when(() => inventoryBloc.stream).thenAnswer((_) => stateController.stream);
  });

  tearDown(() {
    stateController.close();
  });

  Widget buildWidget({ThemeMode themeMode = ThemeMode.light}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InventoryBloc>.value(value: inventoryBloc),
        BlocProvider<ShoppingBadgeCubit>.value(value: badgeCubit),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: const InventoryPage(),
      ),
    );
  }

  group('InventoryPage SnackBar and Undo lifecycle', () {
    testWidgets('Rapid deletes: deleting B while A snackbar is visible evicts A, shows B, undo restores B', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final resultA = makeResult(itemA, PantryEventReason.deleted);
      final msgA = UiMessage<ConsumeResult>.create(
        text: 'Deleted "Apple"',
        type: UiMessageType.undo,
        actionLabel: 'Undo',
        payload: resultA,
      );

      // 1. Delete item A
      final stateA = InventoryState(
        status: InventoryStatus.success,
        items: [itemB],
        totalItemCount: 1,
        uiMessage: msgA,
      );
      when(() => inventoryBloc.state).thenReturn(stateA);
      stateController.add(stateA);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Deleted "Apple"'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // 2. Rapidly delete item B before A times out
      final resultB = makeResult(itemB, PantryEventReason.deleted);
      final msgB = UiMessage<ConsumeResult>.create(
        text: 'Deleted "Banana"',
        type: UiMessageType.undo,
        actionLabel: 'Undo',
        payload: resultB,
      );

      final stateB = InventoryState(
        status: InventoryStatus.success,
        items: const [],
        totalItemCount: 0,
        uiMessage: msgB,
      );
      when(() => inventoryBloc.state).thenReturn(stateB);
      stateController.add(stateB);
      await tester.pump();
      await tester.pumpAndSettle();

      // Only ONE banner is visible, showing B
      expect(find.text('Deleted "Apple"'), findsNothing);
      expect(find.text('Deleted "Banana"'), findsOneWidget);
      expect(find.byKey(const Key('app_top_banner')), findsOneWidget);

      // 3. Tap Undo: restores only B
      await tester.tap(find.text('Undo'));
      await tester.pump();

      verify(() => inventoryBloc.add(InventoryConsumeUndone(resultB))).called(1);
      verifyNever(() => inventoryBloc.add(InventoryConsumeUndone(resultA)));
    });

    testWidgets('Timeout cleanup: snackbar timeout dispatches InventoryMessageDismissed to clean BLoC state', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final result = makeResult(itemA, PantryEventReason.deleted);
      final msg = UiMessage<ConsumeResult>.create(
        text: 'Deleted "Apple"',
        type: UiMessageType.undo,
        actionLabel: 'Undo',
        payload: result,
      );

      final state = InventoryState(
        status: InventoryStatus.success,
        items: [itemB],
        totalItemCount: 1,
        uiMessage: msg,
      );
      when(() => inventoryBloc.state).thenReturn(state);
      stateController.add(state);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Deleted "Apple"'), findsOneWidget);

      // Let the 6-second action duration expire
      await tester.pump();
      await tester.pump(const Duration(seconds: 6, milliseconds: 200));
      await tester.pumpAndSettle();

      // Cleaned up and dismissed event sent
      expect(find.text('Deleted "Apple"'), findsNothing);
      verify(() => inventoryBloc.add(const InventoryMessageDismissed())).called(1);
    });

    testWidgets('Rebuild idempotency: toggling theme or rebuilding does not re-trigger SnackBar', (tester) async {
      await tester.pumpWidget(buildWidget(themeMode: ThemeMode.light));
      await tester.pumpAndSettle();

      final result = makeResult(itemA, PantryEventReason.deleted);
      final msg = UiMessage<ConsumeResult>.create(
        text: 'Deleted "Apple"',
        type: UiMessageType.undo,
        actionLabel: 'Undo',
        payload: result,
      );

      final stateWithMsg = InventoryState(
        status: InventoryStatus.success,
        items: [itemB],
        totalItemCount: 1,
        uiMessage: msg,
      );
      when(() => inventoryBloc.state).thenReturn(stateWithMsg);
      stateController.add(stateWithMsg);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Deleted "Apple"'), findsOneWidget);

      // Rebuild widget tree with dark theme without changing state
      await tester.pumpWidget(buildWidget(themeMode: ThemeMode.dark));
      await tester.pump();

      // State did not change id, so no duplicate snackbar was pushed
      expect(find.byKey(const Key('app_top_banner')), findsOneWidget);
      expect(find.text('Deleted "Apple"'), findsOneWidget);
    });

    testWidgets('Message text correctness: Used up (added to shopping list)', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final result = makeResult(itemA, PantryEventReason.used, shoppingId: 99);
      final msg = UiMessage<ConsumeResult>.create(
        text: 'Added "Apple" to shopping list',
        type: UiMessageType.undo,
        actionLabel: 'Undo',
        payload: result,
      );

      final state = InventoryState(
        status: InventoryStatus.success,
        items: [itemB],
        totalItemCount: 1,
        uiMessage: msg,
      );
      when(() => inventoryBloc.state).thenReturn(state);
      stateController.add(state);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Added "Apple" to shopping list'), findsOneWidget);
    });

    testWidgets('Message text correctness: Used up (removed from inventory)', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final result = makeResult(itemA, PantryEventReason.used);
      final msg = UiMessage<ConsumeResult>.create(
        text: 'Used up "Apple"',
        type: UiMessageType.undo,
        actionLabel: 'Undo',
        payload: result,
      );

      final state = InventoryState(
        status: InventoryStatus.success,
        items: [itemB],
        totalItemCount: 1,
        uiMessage: msg,
      );
      when(() => inventoryBloc.state).thenReturn(state);
      stateController.add(state);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Used up "Apple"'), findsOneWidget);
    });

    testWidgets('Message text correctness: Threw away', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final result = makeResult(itemA, PantryEventReason.wasted);
      final msg = UiMessage<ConsumeResult>.create(
        text: 'Marked "Apple" as thrown away',
        type: UiMessageType.undo,
        actionLabel: 'Undo',
        payload: result,
      );

      final state = InventoryState(
        status: InventoryStatus.success,
        items: [itemB],
        totalItemCount: 1,
        uiMessage: msg,
      );
      when(() => inventoryBloc.state).thenReturn(state);
      stateController.add(state);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Marked "Apple" as thrown away'), findsOneWidget);
    });
  });
}
