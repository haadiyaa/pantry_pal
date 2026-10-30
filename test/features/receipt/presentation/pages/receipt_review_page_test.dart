import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_sync_service.dart';
import 'package:pantry_pal/features/receipt/domain/models/draft_item.dart';
import 'package:pantry_pal/features/receipt/domain/models/receipt_draft.dart';
import 'package:pantry_pal/features/receipt/presentation/pages/receipt_review_page.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class MockNotificationSyncService extends Mock
    implements NotificationSyncService {}

class MockInventoryBloc extends MockBloc<InventoryEvent, InventoryState>
    implements InventoryBloc {}

class FakePantryItem extends Fake implements PantryItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(const InventoryStarted());
    registerFallbackValue(FakePantryItem());
    registerFallbackValue(<PantryItem>[]);
  });

  late MockPantryRepository mockPantryRepo;
  late MockNotificationSyncService mockSyncService;
  late MockInventoryBloc mockInventoryBloc;

  setUp(() {
    mockPantryRepo = MockPantryRepository();
    mockSyncService = MockNotificationSyncService();
    mockInventoryBloc = MockInventoryBloc();

    when(() => mockPantryRepo.getAll()).thenAnswer((_) async => []);
    when(() => mockPantryRepo.addAll(any())).thenAnswer((_) async => [1]);
    when(() => mockSyncService.syncNotifications()).thenAnswer((_) async {});
    when(() => mockInventoryBloc.state).thenReturn(const InventoryState());
  });

  Widget buildReviewScreen(ReceiptDraft draft) {
    final router = GoRouter(
      initialLocation: '/review',
      routes: [
        GoRoute(
          path: '/review',
          builder: (context, state) => ReceiptReviewPage(draft: draft),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Text('Inventory Root'),
          ),
        ),
      ],
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PantryRepository>.value(value: mockPantryRepo),
        RepositoryProvider<NotificationSyncService>.value(
          value: mockSyncService,
        ),
      ],
      child: BlocProvider<InventoryBloc>.value(
        value: mockInventoryBloc,
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets(
      'ReceiptReviewPage allows editing a row, unchecking a row, and saving only included rows',
      (tester) async {
    final testDraft = ReceiptDraft(
      receiptDate: DateTime(2026, 10, 30),
      items: [
        DraftItem(
          name: 'Bread',
          quantity: 1,
          priceInPaise: 4000,
          category: 'Grains',
          suggestedExpiryDate: DateTime(2026, 11, 15),
        ),
        DraftItem(
          name: 'Milk',
          quantity: 2,
          priceInPaise: 6000,
          category: 'Dairy',
          suggestedExpiryDate: DateTime(2026, 11, 6),
        ),
      ],
    );

    await tester.pumpWidget(buildReviewScreen(testDraft));
    await tester.pumpAndSettle();

    // Verify initial header and rows are displayed
    expect(find.text('Review Receipt Items'), findsOneWidget);
    expect(find.text('Found 2 items'), findsOneWidget);
    expect(find.text('Save 2 Items to Pantry'), findsOneWidget);

    // 1. Edit row 0: Change item name to "Whole Wheat Bread" and increment quantity
    final nameField0 = find.byKey(const Key('name_field_item_0'));
    expect(nameField0, findsOneWidget);
    await tester.enterText(nameField0, 'Whole Wheat Bread');
    await tester.pumpAndSettle();

    final incrementQty0 = find.byKey(const Key('increment_qty_item_0'));
    await tester.tap(incrementQty0);
    await tester.pumpAndSettle();

    // Quantity text for item_0 should now show 2
    expect(find.byKey(const Key('qty_text_item_0')), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    // 2. Uncheck row 1 ("Milk")
    final checkbox1 = find.byKey(const Key('checkbox_item_1'));
    expect(checkbox1, findsOneWidget);
    await tester.tap(checkbox1);
    await tester.pumpAndSettle();

    // Bottom button should now reflect saving 1 item
    expect(find.text('Save 1 Items to Pantry'), findsOneWidget);

    // 3. Tap Save button
    final saveButton = find.byKey(const Key('save_receipt_items_button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 4. Verify repository.addAll was called with only the edited, checked row
    final captured = verify(() => mockPantryRepo.addAll(captureAny())).captured;
    expect(captured.length, 1);
    final savedItems = captured.first as List<PantryItem>;
    expect(savedItems.length, 1);
    expect(savedItems.first.name, 'Whole Wheat Bread');
    expect(savedItems.first.quantity, 2);
    expect(savedItems.first.priceInPaise, 4000);
    expect(savedItems.first.category, 'Grains');

    // Verify notifications were rescheduled and inventory bloc was refreshed
    verify(() => mockSyncService.syncNotifications()).called(1);
    verify(() => mockInventoryBloc.add(const InventoryStarted())).called(1);

    // Verify routed back to inventory page
    expect(find.text('Inventory Root'), findsOneWidget);
  });
}

