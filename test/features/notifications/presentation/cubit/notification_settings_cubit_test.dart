import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/notifications/domain/models/notification_settings.dart';
import 'package:pantry_pal/features/notifications/domain/models/planned_notification.dart';
import 'package:pantry_pal/features/notifications/domain/repositories/notification_settings_repository.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_scheduler.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_sync_service.dart';
import 'package:pantry_pal/features/notifications/presentation/cubit/notification_settings_cubit.dart';
import 'package:pantry_pal/features/notifications/presentation/cubit/notification_settings_state.dart';

class MockNotificationSettingsRepository extends Mock
    implements NotificationSettingsRepository {}

class MockNotificationScheduler extends Mock
    implements NotificationScheduler {}

class MockNotificationSyncService extends Mock
    implements NotificationSyncService {}

class FakeNotificationSettings extends Fake implements NotificationSettings {}

class FakePlannedNotification extends Fake implements PlannedNotification {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNotificationSettings());
    registerFallbackValue(FakePlannedNotification());
  });

  late MockNotificationSettingsRepository settingsRepo;
  late MockNotificationScheduler scheduler;
  late MockNotificationSyncService syncService;

  setUp(() {
    settingsRepo = MockNotificationSettingsRepository();
    scheduler = MockNotificationScheduler();
    syncService = MockNotificationSyncService();

    when(() => settingsRepo.loadSettings()).thenAnswer(
      (_) async => const NotificationSettings(),
    );
    when(() => settingsRepo.saveSettings(any())).thenAnswer((_) async {});
    when(() => scheduler.checkPermission()).thenAnswer((_) async => false);
    when(() => scheduler.cancelAll()).thenAnswer((_) async {});
    when(() => syncService.syncNotifications()).thenAnswer((_) async {});
  });

  NotificationSettingsCubit buildCubit() {
    return NotificationSettingsCubit(
      settingsRepository: settingsRepo,
      scheduler: scheduler,
      syncService: syncService,
    );
  }

  group('NotificationSettingsCubit', () {
    test('initial state has default settings and initial permission status', () {
      final cubit = buildCubit();
      expect(cubit.state.settings, const NotificationSettings());
      expect(cubit.state.permissionStatus, NotificationPermissionStatus.initial);
      expect(cubit.state.isLoading, isFalse);
    });

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'loadSettings loads stored settings and checks permission',
      build: () {
        when(() => settingsRepo.loadSettings()).thenAnswer(
          (_) async => const NotificationSettings(
            notificationsEnabled: true,
            reminderHour: 8,
            reminderMinute: 30,
            daysBefore: 3,
            digestEnabled: false,
          ),
        );
        when(() => scheduler.checkPermission()).thenAnswer((_) async => true);
        return buildCubit();
      },
      act: (cubit) => cubit.loadSettings(),
      expect: () => [
        const NotificationSettingsState(isLoading: true),
        const NotificationSettingsState(
          settings: NotificationSettings(
            notificationsEnabled: true,
            reminderHour: 8,
            reminderMinute: 30,
            daysBefore: 3,
            digestEnabled: false,
          ),
          permissionStatus: NotificationPermissionStatus.granted,
          isLoading: false,
        ),
      ],
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'toggleNotifications on when permission granted updates state, saves, and syncs',
      build: () {
        when(() => scheduler.requestPermission()).thenAnswer((_) async => true);
        return buildCubit();
      },
      act: (cubit) => cubit.toggleNotifications(true),
      expect: () => [
        const NotificationSettingsState(
          settings: NotificationSettings(notificationsEnabled: true),
          permissionStatus: NotificationPermissionStatus.granted,
        ),
      ],
      verify: (_) {
        verify(() => settingsRepo.saveSettings(const NotificationSettings(notificationsEnabled: true))).called(1);
        verify(() => syncService.syncNotifications()).called(1);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'toggleNotifications on when permission denied does NOT enable notifications',
      build: () {
        when(() => scheduler.requestPermission()).thenAnswer((_) async => false);
        return buildCubit();
      },
      act: (cubit) => cubit.toggleNotifications(true),
      expect: () => [
        const NotificationSettingsState(
          settings: NotificationSettings(notificationsEnabled: false),
          permissionStatus: NotificationPermissionStatus.denied,
        ),
      ],
      verify: (_) {
        verify(() => settingsRepo.saveSettings(const NotificationSettings(notificationsEnabled: false))).called(1);
        verifyNever(() => syncService.syncNotifications());
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'toggleNotifications off cancels all scheduled notifications and saves',
      build: buildCubit,
      seed: () => const NotificationSettingsState(
        settings: NotificationSettings(notificationsEnabled: true),
        permissionStatus: NotificationPermissionStatus.granted,
      ),
      act: (cubit) => cubit.toggleNotifications(false),
      expect: () => [
        const NotificationSettingsState(
          settings: NotificationSettings(notificationsEnabled: false),
          permissionStatus: NotificationPermissionStatus.granted,
        ),
      ],
      verify: (_) {
        verify(() => settingsRepo.saveSettings(const NotificationSettings(notificationsEnabled: false))).called(1);
        verify(() => scheduler.cancelAll()).called(1);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'updateReminderTime reschedules notifications when enabled',
      build: buildCubit,
      seed: () => const NotificationSettingsState(
        settings: NotificationSettings(notificationsEnabled: true),
        permissionStatus: NotificationPermissionStatus.granted,
      ),
      act: (cubit) => cubit.updateReminderTime(10, 15),
      expect: () => [
        const NotificationSettingsState(
          settings: NotificationSettings(
            notificationsEnabled: true,
            reminderHour: 10,
            reminderMinute: 15,
          ),
          permissionStatus: NotificationPermissionStatus.granted,
        ),
      ],
      verify: (_) {
        verify(() => syncService.syncNotifications()).called(1);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'updateDaysBefore reschedules notifications when enabled',
      build: buildCubit,
      seed: () => const NotificationSettingsState(
        settings: NotificationSettings(notificationsEnabled: true),
        permissionStatus: NotificationPermissionStatus.granted,
      ),
      act: (cubit) => cubit.updateDaysBefore(4),
      expect: () => [
        const NotificationSettingsState(
          settings: NotificationSettings(
            notificationsEnabled: true,
            daysBefore: 4,
          ),
          permissionStatus: NotificationPermissionStatus.granted,
        ),
      ],
      verify: (_) {
        verify(() => syncService.syncNotifications()).called(1);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'toggleDigest reschedules notifications when enabled',
      build: buildCubit,
      seed: () => const NotificationSettingsState(
        settings: NotificationSettings(notificationsEnabled: true),
        permissionStatus: NotificationPermissionStatus.granted,
      ),
      act: (cubit) => cubit.toggleDigest(false),
      expect: () => [
        const NotificationSettingsState(
          settings: NotificationSettings(
            notificationsEnabled: true,
            digestEnabled: false,
          ),
          permissionStatus: NotificationPermissionStatus.granted,
        ),
      ],
      verify: (_) {
        verify(() => syncService.syncNotifications()).called(1);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'sendTestNotification calls scheduler showTestNotification',
      build: () {
        when(() => scheduler.showTestNotification(any())).thenAnswer((_) async {});
        return buildCubit();
      },
      act: (cubit) => cubit.sendTestNotification(),
      expect: () => [
        isA<NotificationSettingsState>().having(
          (s) => s.testNotificationSent,
          'testNotificationSent',
          isTrue,
        ),
      ],
      verify: (_) {
        verify(() => scheduler.showTestNotification(any())).called(1);
      },
    );
  });
}

