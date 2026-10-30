import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/consume_result.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event_reason.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_sync_service.dart';
import 'package:pantry_pal/features/shopping/domain/repositories/shopping_settings_repository.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class MockNotificationSyncService extends Mock
    implements NotificationSyncService {}

class MockShoppingSettingsRepository extends Mock
    implements ShoppingSettingsRepository {}

void main() {
  late MockPantryRepository repository;
  late MockNotificationSyncService syncService;
  late MockShoppingSettingsRepository settingsRepo;

  final fixedDate = DateTime(2026, 6, 1);

  final sampleItem = PantryItem(
    id: 1,
    name: 'Whole Milk',
    quantity: 2,
    category: 'Dairy',
    expiryDate: fixedDate.add(const Duration(days: 3)),
    addedAt: fixedDate,
  );

  final sampleConsumeResult = ConsumeResult(
    item: sampleItem,
    event: PantryEvent(
      id: 10,
      itemName: 'Whole Milk',
      category: 'Dairy',
      quantity: 1,
      reason: PantryEventReason.used,
      occurredAt: fixedDate,
    ),
    previousQuantity: 2,
    wasRemoved: false,
  );

  setUpAll(() {
    registerFallbackValue(sampleItem);
    registerFallbackValue(sampleConsumeResult);
    registerFallbackValue(PantryEventReason.used);
  });

  setUp(() {
    repository = MockPantryRepository();
    syncService = MockNotificationSyncService();
    settingsRepo = MockShoppingSettingsRepository();

    when(() => repository.search(
          query: any(named: 'query'),
          categories: any(named: 'categories'),
          expiringWithinDays: any(named: 'expiringWithinDays'),
        )).thenAnswer((_) async => []);
    when(() => repository.countAll()).thenAnswer((_) async => 0);
    when(() => syncService.syncNotifications()).thenAnswer((_) async => 0);
    when(() => settingsRepo.getAddUsedUpToShoppingList())
        .thenAnswer((_) async => true);
  });

  group('InventoryBloc removal actions (Step 7)', () {
    blocTest<InventoryBloc, InventoryState>(
      'InventoryItemUsedUp consumes item with reason used and emits lastConsumeResult',
      build: () {
        when(
          () => repository.consume(
            item: sampleItem,
            reason: PantryEventReason.used,
            addToShoppingList: true,
          ),
        ).thenAnswer((_) async => sampleConsumeResult);
        return InventoryBloc(
          repository,
          notificationSyncService: syncService,
          shoppingSettingsRepository: settingsRepo,
        );
      },
      act: (bloc) => bloc.add(InventoryItemUsedUp(sampleItem)),
      expect: () => [
        isA<InventoryState>().having(
          (s) => s.lastConsumeResult,
          'lastConsumeResult',
          sampleConsumeResult,
        ),
        isA<InventoryState>().having(
          (s) => s.status,
          'status',
          InventoryStatus.loading,
        ),
        isA<InventoryState>().having(
          (s) => s.status,
          'status',
          InventoryStatus.success,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.consume(
            item: sampleItem,
            reason: PantryEventReason.used,
            addToShoppingList: true,
          ),
        ).called(1);
        verify(() => syncService.syncNotifications()).called(1);
      },
    );

    blocTest<InventoryBloc, InventoryState>(
      'InventoryItemUsedUp respects auto-add setting when false',
      build: () {
        when(() => settingsRepo.getAddUsedUpToShoppingList())
            .thenAnswer((_) async => false);
        when(
          () => repository.consume(
            item: sampleItem,
            reason: PantryEventReason.used,
            addToShoppingList: false,
          ),
        ).thenAnswer((_) async => sampleConsumeResult);
        return InventoryBloc(
          repository,
          notificationSyncService: syncService,
          shoppingSettingsRepository: settingsRepo,
        );
      },
      act: (bloc) => bloc.add(InventoryItemUsedUp(sampleItem)),
      verify: (_) {
        verify(
          () => repository.consume(
            item: sampleItem,
            reason: PantryEventReason.used,
            addToShoppingList: false,
          ),
        ).called(1);
      },
    );

    blocTest<InventoryBloc, InventoryState>(
      'InventoryItemWasted consumes item with reason wasted and does NOT add to shopping list',
      build: () {
        final wasteResult = ConsumeResult(
          item: sampleItem,
          event: PantryEvent(
            id: 11,
            itemName: 'Whole Milk',
            category: 'Dairy',
            quantity: 2,
            reason: PantryEventReason.wasted,
            occurredAt: fixedDate,
          ),
          previousQuantity: 2,
          wasRemoved: true,
        );

        when(
          () => repository.consume(
            item: sampleItem,
            reason: PantryEventReason.wasted,
            addToShoppingList: false,
          ),
        ).thenAnswer((_) async => wasteResult);
        return InventoryBloc(
          repository,
          notificationSyncService: syncService,
          shoppingSettingsRepository: settingsRepo,
        );
      },
      act: (bloc) => bloc.add(InventoryItemWasted(sampleItem)),
      expect: () => [
        isA<InventoryState>().having(
          (s) => s.lastConsumeResult?.event.reason,
          'reason',
          PantryEventReason.wasted,
        ),
        isA<InventoryState>().having(
          (s) => s.status,
          'status',
          InventoryStatus.loading,
        ),
        isA<InventoryState>().having(
          (s) => s.status,
          'status',
          InventoryStatus.success,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.consume(
            item: sampleItem,
            reason: PantryEventReason.wasted,
            addToShoppingList: false,
          ),
        ).called(1);
        verify(() => syncService.syncNotifications()).called(1);
      },
    );

    blocTest<InventoryBloc, InventoryState>(
      'InventoryConsumeUndone undoes consume transaction and clears lastConsumeResult',
      build: () {
        when(() => repository.undoConsume(sampleConsumeResult))
            .thenAnswer((_) async {});
        return InventoryBloc(
          repository,
          notificationSyncService: syncService,
          shoppingSettingsRepository: settingsRepo,
        );
      },
      seed: () => InventoryState(
        status: InventoryStatus.success,
        items: const [],
        totalItemCount: 0,
        lastConsumeResult: sampleConsumeResult,
      ),
      act: (bloc) => bloc.add(InventoryConsumeUndone(sampleConsumeResult)),
      expect: () => [
        isA<InventoryState>().having(
          (s) => s.lastConsumeResult,
          'lastConsumeResult',
          isNull,
        ),
      ],
      verify: (_) {
        verify(() => repository.undoConsume(sampleConsumeResult)).called(1);
        verify(() => syncService.syncNotifications()).called(1);
      },
    );
  });
}
