import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_sync_service.dart';
import 'package:pantry_pal/features/receipt/domain/models/draft_item.dart';
import 'package:pantry_pal/features/receipt/domain/models/receipt_draft.dart';
import 'package:pantry_pal/features/receipt/presentation/cubit/receipt_review_cubit.dart';
import 'package:pantry_pal/features/receipt/presentation/cubit/receipt_review_item.dart';
import 'package:pantry_pal/features/receipt/presentation/cubit/receipt_review_state.dart';

class MockPantryRepository extends Mock implements PantryRepository {}
class MockNotificationSyncService extends Mock implements NotificationSyncService {}
class FakePantryItem extends Fake implements PantryItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePantryItem());
    registerFallbackValue(<PantryItem>[]);
  });

  late MockPantryRepository pantryRepository;
  late MockNotificationSyncService notificationSyncService;

  setUp(() {
    pantryRepository = MockPantryRepository();
    notificationSyncService = MockNotificationSyncService();
  });

  final testDate = DateTime(2026, 11, 5);
  final existingPantryItems = [
    PantryItem(
      id: 101,
      name: 'Amul Milk',
      quantity: 1,
      category: 'Dairy',
      expiryDate: testDate,
      addedAt: DateTime(2026, 10, 20),
    ),
  ];

  final sampleDraft = ReceiptDraft(
    receiptDate: DateTime(2026, 10, 28),
    items: [
      DraftItem(
        name: 'Amul Milk', // Duplicate!
        quantity: 2,
        priceInPaise: 6400,
        category: 'Dairy',
        confidence: ItemConfidence.high,
        suggestedExpiryDate: testDate,
      ),
      DraftItem(
        name: 'Bread',
        quantity: 1,
        priceInPaise: 4000,
        category: 'Grains',
        confidence: ItemConfidence.low, // Low confidence!
        suggestedExpiryDate: testDate,
      ),
    ],
  );

  group('ReceiptReviewCubit', () {
    test('initial state has empty items and initial status', () {
      final cubit = ReceiptReviewCubit(
        pantryRepository: pantryRepository,
        notificationSyncService: notificationSyncService,
      );

      expect(cubit.state.status, ReceiptReviewStatus.initial);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.includedCount, 0);
    });

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'initialize loads draft, detects existing pantry duplicate, and sorts low-confidence first',
      build: () {
        when(() => pantryRepository.getAll())
            .thenAnswer((_) async => existingPantryItems);
        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) => cubit.initialize(sampleDraft),
      expect: () => [
        isA<ReceiptReviewState>().having((s) => s.status, 'status', ReceiptReviewStatus.loading),
        isA<ReceiptReviewState>()
            .having((s) => s.status, 'status', ReceiptReviewStatus.ready)
            .having((s) => s.items.length, 'items length', 2)
            // Low confidence item (Bread) sorted first
            .having((s) => s.items.first.name, 'first item is low confidence', 'Bread')
            .having((s) => s.items.first.isLowConfidence, 'isLowConfidence', isTrue)
            // Duplicate detected for Amul Milk
            .having((s) => s.items.last.isDuplicate, 'duplicate detected', isTrue)
            .having((s) => s.items.last.existingItemId, 'existingItemId', 101)
            .having((s) => s.items.last.existingItemQuantity, 'existingItemQuantity', 1),
      ],
    );

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'toggleInclude flips inclusion state and updates includedCount',
      build: () {
        when(() => pantryRepository.getAll()).thenAnswer((_) async => []);
        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) async {
        await cubit.initialize(sampleDraft);
        final firstId = cubit.state.items.first.id;
        cubit.toggleInclude(firstId);
      },
      verify: (cubit) {
        expect(cubit.state.items.first.isIncluded, isFalse);
        expect(cubit.state.includedCount, 1);
      },
    );

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'selectAll includes or excludes all items',
      build: () {
        when(() => pantryRepository.getAll()).thenAnswer((_) async => []);
        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) async {
        await cubit.initialize(sampleDraft);
        cubit.selectAll(false);
        expect(cubit.state.includedCount, 0);
        cubit.selectAll(true);
        expect(cubit.state.includedCount, 2);
      },
    );

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'update fields (name, qty, category, expiryDate, price) modifies the item',
      build: () {
        when(() => pantryRepository.getAll()).thenAnswer((_) async => []);
        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) async {
        await cubit.initialize(sampleDraft);
        final id = cubit.state.items.first.id;
        cubit.updateName(id, 'Brown Bread');
        cubit.updateQuantity(id, 3);
        cubit.updateCategory(id, 'Grains');
        cubit.updatePrice(id, 5500);
        cubit.updateExpiryDate(id, DateTime(2026, 12, 1));
      },
      verify: (cubit) {
        final item = cubit.state.items.first;
        expect(item.name, 'Brown Bread');
        expect(item.quantity, 3);
        expect(item.category, 'Grains');
        expect(item.priceInPaise, 5500);
        expect(item.expiryDate, DateTime(2026, 12, 1));
      },
    );

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'deleteItem removes row and addItem appends a manual row',
      build: () {
        when(() => pantryRepository.getAll()).thenAnswer((_) async => []);
        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) async {
        await cubit.initialize(sampleDraft);
        final firstId = cubit.state.items.first.id;
        cubit.deleteItem(firstId);
        expect(cubit.state.items.length, 1);
        cubit.addItem();
        expect(cubit.state.items.length, 2);
      },
    );

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'saveAll saves new items via addAll and updates existing duplicate when chosen',
      build: () {
        when(() => pantryRepository.getAll())
            .thenAnswer((_) async => existingPantryItems);
        when(() => pantryRepository.getById(101))
            .thenAnswer((_) async => existingPantryItems.first);
        when(() => pantryRepository.update(any())).thenAnswer((_) async {});
        when(() => pantryRepository.addAll(any())).thenAnswer((_) async {});
        when(() => notificationSyncService.syncNotifications())
            .thenAnswer((_) async {});

        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) async {
        await cubit.initialize(sampleDraft);

        // Amul Milk item (duplicate) set to increment existing
        final duplicateItem = cubit.state.items.firstWhere((i) => i.isDuplicate);
        cubit.setDuplicateResolution(
          duplicateItem.id,
          DuplicateResolution.incrementExisting,
        );

        await cubit.saveAll();
      },
      verify: (cubit) {
        expect(cubit.state.status, ReceiptReviewStatus.saveSuccess);
        expect(cubit.state.savedCount, 2);

        // Verify update called for duplicate: 1 (existing) + 2 (scanned) = 3
        verify(
          () => pantryRepository.update(
            any(
              that: isA<PantryItem>()
                  .having((i) => i.id, 'id', 101)
                  .having((i) => i.quantity, 'quantity', 3),
            ),
          ),
        ).called(1);

        // Verify addAll called for the other new item (Bread)
        verify(
          () => pantryRepository.addAll(
            any(
              that: isA<List<PantryItem>>()
                  .having((l) => l.length, 'length', 1)
                  .having((l) => l.first.name, 'name', 'Bread'),
            ),
          ),
        ).called(1);

        // Verify notifications resynced
        verify(() => notificationSyncService.syncNotifications()).called(1);
      },
    );

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'saveAll skips unchecked rows and saves only included rows',
      build: () {
        when(() => pantryRepository.getAll()).thenAnswer((_) async => []);
        when(() => pantryRepository.addAll(any())).thenAnswer((_) async {});
        when(() => notificationSyncService.syncNotifications())
            .thenAnswer((_) async {});

        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) async {
        await cubit.initialize(sampleDraft);
        // Uncheck the first item
        cubit.toggleInclude(cubit.state.items.first.id);
        await cubit.saveAll();
      },
      verify: (cubit) {
        expect(cubit.state.status, ReceiptReviewStatus.saveSuccess);
        expect(cubit.state.savedCount, 1);

        verify(
          () => pantryRepository.addAll(
            any(
              that: isA<List<PantryItem>>().having((l) => l.length, 'length', 1),
            ),
          ),
        ).called(1);
      },
    );

    blocTest<ReceiptReviewCubit, ReceiptReviewState>(
      'saveAll emits failure when repository throws an exception',
      build: () {
        when(() => pantryRepository.getAll()).thenAnswer((_) async => []);
        when(() => pantryRepository.addAll(any()))
            .thenThrow(Exception('Database disk full'));

        return ReceiptReviewCubit(
          pantryRepository: pantryRepository,
          notificationSyncService: notificationSyncService,
        );
      },
      act: (cubit) async {
        await cubit.initialize(sampleDraft);
        await cubit.saveAll();
      },
      expect: () => [
        isA<ReceiptReviewState>().having((s) => s.status, 'status', ReceiptReviewStatus.loading),
        isA<ReceiptReviewState>().having((s) => s.status, 'status', ReceiptReviewStatus.ready),
        isA<ReceiptReviewState>().having((s) => s.status, 'status', ReceiptReviewStatus.saving),
        isA<ReceiptReviewState>()
            .having((s) => s.status, 'status', ReceiptReviewStatus.failure)
            .having((s) => s.errorMessage, 'errorMessage', contains('Database disk full')),
      ],
    );
  });
}

