import '../models/notification_settings.dart';

abstract interface class NotificationSettingsRepository {
  Future<NotificationSettings> loadSettings();
  Future<void> saveSettings(NotificationSettings settings);
}

