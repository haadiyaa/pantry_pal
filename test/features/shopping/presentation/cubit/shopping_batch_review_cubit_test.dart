import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_sync_service.dart';
import 'package:pantry_pal/features/receipt/domain/services/expiry_suggester.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_item.dart';
import 'package:pantry_pal/features/shopping/domain/models/shopping_source_type.dart';
import 'package:pantry_pal/features/shopping/domain/repositories/shopping_repository.dart';
import 'package:pantry_pal/features/shopping/presentation/cubit/shopping_batch_review_cubit.dart';
import 'package:pantry_pal/features/shopping/presentation/cubit/shopping_batch_review_state.dart';

class MockShoppingRepository extends Mock implements ShoppingRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

class MockNotificationSyncService extends Mock
    implements NotificationSyncService {}

void main() {
  late MockShoppingRepository shoppingRepo;
  late MockPantryRepository pantryRepo;
  late MockNotificationSyncService syncService;

  final fixedNow = DateTime(2026, 6, 1, 10, 0);

  final sampleBought1 = ShoppingItem(
    id: 1,
    name: 'Greek Yogurt',
    normalizedName: 'greek yogurt',
    quantity: 2,
    category: 'Dairy',
    isBought: true,
    sourceType: ShoppingSourceType.manual,
    addedAt: fixedNow,
  );

  final sampleBought2 = ShoppingItem(
    id: 2,
    name: 'Tomatoes',
    normalizedName: 'tomatoes',
    quantity: 5,
    category: 'Produce',
    isBought: true,
    sourceType: ShoppingSourceType.recipe,
    addedAt: fixedNow,
  );

  setUpAll(() {
    registerFallbackValue(sampleBought1);
    registerFallbackValue(<PantryItem>[]);
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    shoppingRepo = MockShoppingRepository();
    pantryRepo = MockPantryRepository();
    syncService = MockNotificationSyncService();

    when(() => syncService.syncNotifications()).thenAnswer((_) async => 0);
  });

  group('ShoppingBatchReviewCubit', () {
    test('initializes with estimated expiry dates and all items included', () {
      final cubit = ShoppingBatchReviewCubit(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        notificationSyncService: syncService,
        boughtItems: [sampleBought1, sampleBought2],
        expirySuggester: const ExpirySuggester(),
        nowProvider: () => fixedNow,
      );

      expect(cubit.state.items.length, equals(2));
      expect(cubit.state.includedCount, equals(2));

      final first = cubit.state.items.first;
      expect(first.name, equals('Greek Yogurt'));
      expect(first.quantity, equals(2));
      expect(first.category, equals('Dairy'));
      expect(first.isIncluded, isTrue);
      expect(first.isEstimated, isTrue);
      // Dairy default suggestion is +7 days
      expect(first.expiryDate, equals(DateTime(2026, 6, 8)));

      final second = cubit.state.items[1];
      expect(second.name, equals('Tomatoes'));
      expect(second.quantity, equals(5));
      expect(second.category, equals('Produce'));
      // Other/fallback suggestion is +30 days
      expect(second.expiryDate, equals(DateTime(2026, 7, 1)));
    });

    test('nameChanged updates item name', () {
      final cubit = ShoppingBatchReviewCubit(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        boughtItems: [sampleBought1],
        nowProvider: () => fixedNow,
      );

      cubit.nameChanged(1, 'Organic Greek Yogurt');
      expect(cubit.state.items.first.name, equals('Organic Greek Yogurt'));
    });

    test('quantityChanged updates quantity and ignores values < 1', () {
      final cubit = ShoppingBatchReviewCubit(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        boughtItems: [sampleBought1],
        nowProvider: () => fixedNow,
      );

      cubit.quantityChanged(1, 4);
      expect(cubit.state.items.first.quantity, equals(4));

      cubit.quantityChanged(1, 0);
      expect(cubit.state.items.first.quantity, equals(4));
    });

    test('categoryChanged recalculates expiry when isEstimated is true', () {
      final cubit = ShoppingBatchReviewCubit(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        boughtItems: [sampleBought1],
        nowProvider: () => fixedNow,
      );

      // Change category from Dairy (+7d) to Grains (+180d)
      cubit.categoryChanged(1, 'Grains');
      expect(cubit.state.items.first.category, equals('Grains'));
      expect(
        cubit.state.items.first.expiryDate,
        equals(DateTime(2026, 6, 1 + 180)),
      );
    });

    test('expiryDateChanged sets custom date and marks isEstimated as false', () {
      final cubit = ShoppingBatchReviewCubit(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        boughtItems: [sampleBought1],
        nowProvider: () => fixedNow,
      );

      final customDate = fixedNow.add(const Duration(days: 20));
      cubit.expiryDateChanged(1, customDate);

      expect(cubit.state.items.first.expiryDate, equals(customDate));
      expect(cubit.state.items.first.isEstimated, isFalse);

      // Changing category now preserves the user's picked date!
      cubit.categoryChanged(1, 'Meat');
      expect(cubit.state.items.first.category, equals('Meat'));
      expect(cubit.state.items.first.expiryDate, equals(customDate));
    });

    test('toggleIncluded toggles isIncluded and updates includedCount', () {
      final cubit = ShoppingBatchReviewCubit(
        shoppingRepository: shoppingRepo,
        pantryRepository: pantryRepo,
        boughtItems: [sampleBought1, sampleBought2],
        nowProvider: () => fixedNow,
      );

      expect(cubit.state.includedCount, equals(2));

      cubit.toggleIncluded(1);
      expect(cubit.state.items.first.isIncluded, isFalse);
      expect(cubit.state.includedCount, equals(1));

      cubit.toggleIncluded(1);
      expect(cubit.state.items.first.isIncluded, isTrue);
      expect(cubit.state.includedCount, equals(2));
    });

    blocTest<ShoppingBatchReviewCubit, ShoppingBatchReviewState>(
      'saveToPantry moves included items to pantry, resyncs notifications, and emits success',
      build: () {
        when(
          () => shoppingRepo.moveBoughtToPantry(any(), any()),
        ).thenAnswer((_) async {});
        return ShoppingBatchReviewCubit(
          shoppingRepository: shoppingRepo,
          pantryRepository: pantryRepo,
          notificationSyncService: syncService,
          boughtItems: [sampleBought1],
          nowProvider: () => fixedNow,
        );
      },
      act: (cubit) => cubit.saveToPantry(),
      expect: () => [
        isA<ShoppingBatchReviewState>().having(
          (s) => s.status,
          'status',
          ShoppingBatchReviewStatus.submitting,
        ),
        isA<ShoppingBatchReviewState>().having(
          (s) => s.status,
          'status',
          ShoppingBatchReviewStatus.success,
        ),
      ],
      verify: (_) {
        verify(
          () => shoppingRepo.moveBoughtToPantry(
            any(
              that: isA<List<PantryItem>>().having(
                (l) => l.first.name,
                'first item name',
                'Greek Yogurt',
              ),
            ),
            [1],
          ),
        ).called(1);
        verify(() => syncService.syncNotifications()).called(1);
      },
    );
  });
}
