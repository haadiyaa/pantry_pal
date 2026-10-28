import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_sync_service.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class MockNotificationSyncService extends Mock
    implements NotificationSyncService {}

class FakePantryItem extends Fake implements PantryItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePantryItem());
  });

  late MockPantryRepository repository;
  late MockNotificationSyncService syncService;

  setUp(() {
    repository = MockPantryRepository();
    syncService = MockNotificationSyncService();

    when(() => repository.countAll()).thenAnswer((_) async => 0);
    when(() => repository.search(
          query: any(named: 'query'),
          categories: any(named: 'categories'),
          expiringWithinDays: any(named: 'expiringWithinDays'),
        )).thenAnswer((_) async => []);
    when(() => repository.add(any())).thenAnswer((_) async => 1);
    when(() => repository.update(any())).thenAnswer((_) async {});
    when(() => repository.delete(any())).thenAnswer((_) async {});
    when(() => syncService.syncNotifications()).thenAnswer((_) async {});
  });

  final sampleItem = PantryItem(
    id: 1,
    name: 'Yogurt',
    expiryDate: DateTime(2026, 11, 1),
    addedAt: DateTime(2026, 10, 20),
  );

  group('InventoryBloc Notification Rescheduling', () {
    test('InventoryItemAdded triggers notification resync', () async {
      final bloc = InventoryBloc(
        repository,
        notificationSyncService: syncService,
      );

      bloc.add(InventoryItemAdded(sampleItem));
      await untilCalled(() => syncService.syncNotifications());

      verify(() => repository.add(sampleItem)).called(1);
      verify(() => syncService.syncNotifications()).called(1);
      await bloc.close();
    });

    test('InventoryItemUpdated triggers notification resync', () async {
      final bloc = InventoryBloc(
        repository,
        notificationSyncService: syncService,
      );

      bloc.add(InventoryItemUpdated(sampleItem));
      await untilCalled(() => syncService.syncNotifications());

      verify(() => repository.update(sampleItem)).called(1);
      verify(() => syncService.syncNotifications()).called(1);
      await bloc.close();
    });

    test('InventoryItemDeleted triggers notification resync', () async {
      final bloc = InventoryBloc(
        repository,
        notificationSyncService: syncService,
      );

      bloc.add(const InventoryItemDeleted(1));
      await untilCalled(() => syncService.syncNotifications());

      verify(() => repository.delete(1)).called(1);
      verify(() => syncService.syncNotifications()).called(1);
      await bloc.close();
    });

    test('InventoryStarted triggers notification resync on app start', () async {
      final bloc = InventoryBloc(
        repository,
        notificationSyncService: syncService,
      );

      bloc.add(const InventoryStarted());
      await untilCalled(() => syncService.syncNotifications());

      verify(() => syncService.syncNotifications()).called(1);
      await bloc.close();
    });
  });
}

