import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/notifications/data/repositories/shared_preferences_notification_settings_repository.dart';
import 'package:pantry_pal/features/notifications/domain/models/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesNotificationSettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesNotificationSettingsRepository();
  });

  group('SharedPreferencesNotificationSettingsRepository', () {
    test('loadSettings returns default NotificationSettings when empty', () async {
      final settings = await repository.loadSettings();

      expect(settings.notificationsEnabled, isFalse);
      expect(settings.reminderHour, 9);
      expect(settings.reminderMinute, 0);
      expect(settings.daysBefore, 2);
      expect(settings.digestEnabled, isTrue);
    });

    test('saveSettings stores settings and loadSettings reads them back accurately', () async {
      const customSettings = NotificationSettings(
        notificationsEnabled: true,
        reminderHour: 8,
        reminderMinute: 45,
        daysBefore: 3,
        digestEnabled: false,
      );

      await repository.saveSettings(customSettings);
      final loaded = await repository.loadSettings();

      expect(loaded, equals(customSettings));
    });

    test('clamps daysBefore to valid range between 1 and 7', () async {
      SharedPreferences.setMockInitialValues({
        'notifications_days_before': 10,
      });

      final loaded = await repository.loadSettings();
      expect(loaded.daysBefore, 7);
    });
  });
}

