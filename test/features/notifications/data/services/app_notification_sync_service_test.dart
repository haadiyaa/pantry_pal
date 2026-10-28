import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/notifications/data/services/app_notification_sync_service.dart';
import 'package:pantry_pal/features/notifications/domain/models/notification_settings.dart';
import 'package:pantry_pal/features/notifications/domain/models/planned_notification.dart';
import 'package:pantry_pal/features/notifications/domain/repositories/notification_settings_repository.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_scheduler.dart';

class MockPantryRepository extends Mock implements PantryRepository {}

class MockNotificationSettingsRepository extends Mock
    implements NotificationSettingsRepository {}

class MockNotificationScheduler extends Mock
    implements NotificationScheduler {}

class FakePlannedNotification extends Fake implements PlannedNotification {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePlannedNotification());
  });

  late MockPantryRepository pantryRepo;
  late MockNotificationSettingsRepository settingsRepo;
  late MockNotificationScheduler scheduler;
  late AppNotificationSyncService syncService;

  setUp(() {
    pantryRepo = MockPantryRepository();
    settingsRepo = MockNotificationSettingsRepository();
    scheduler = MockNotificationScheduler();

    syncService = AppNotificationSyncService(
      pantryRepository: pantryRepo,
      settingsRepository: settingsRepo,
      scheduler: scheduler,
    );

    when(() => scheduler.cancelAll()).thenAnswer((_) async {});
    when(() => scheduler.schedule(any())).thenAnswer((_) async {});
  });

  group('AppNotificationSyncService', () {
    test('cancels all when notifications are disabled', () async {
      when(() => settingsRepo.loadSettings()).thenAnswer(
        (_) async => const NotificationSettings(notificationsEnabled: false),
      );

      await syncService.syncNotifications();

      verify(() => scheduler.cancelAll()).called(1);
      verifyNever(() => scheduler.schedule(any()));
    });

    test('plans and schedules when notifications are enabled', () async {
      when(() => settingsRepo.loadSettings()).thenAnswer(
        (_) async => const NotificationSettings(notificationsEnabled: true),
      );
      when(() => pantryRepo.search()).thenAnswer(
        (_) async => [
          PantryItem(
            id: 10,
            name: 'Fresh Spinach',
            expiryDate: DateTime.now().add(const Duration(days: 4)),
            addedAt: DateTime.now(),
          ),
        ],
      );

      await syncService.syncNotifications();

      verify(() => scheduler.schedule(any())).called(1);
    });
  });
}

