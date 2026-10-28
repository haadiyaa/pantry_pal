import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/notification_settings.dart';
import '../../domain/repositories/notification_settings_repository.dart';

class SharedPreferencesNotificationSettingsRepository
    implements NotificationSettingsRepository {
  SharedPreferencesNotificationSettingsRepository({SharedPreferences? preferences})
      : _prefs = preferences;

  SharedPreferences? _prefs;

  static const _keyNotificationsEnabled = 'notifications_enabled';
  static const _keyReminderHour = 'notifications_reminder_hour';
  static const _keyReminderMinute = 'notifications_reminder_minute';
  static const _keyDaysBefore = 'notifications_days_before';
  static const _keyDigestEnabled = 'notifications_digest_enabled';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<NotificationSettings> loadSettings() async {
    final prefs = await _getPrefs();
    return NotificationSettings(
      notificationsEnabled: prefs.getBool(_keyNotificationsEnabled) ?? false,
      reminderHour: prefs.getInt(_keyReminderHour) ?? 9,
      reminderMinute: prefs.getInt(_keyReminderMinute) ?? 0,
      daysBefore: (prefs.getInt(_keyDaysBefore) ?? 2).clamp(1, 7),
      digestEnabled: prefs.getBool(_keyDigestEnabled) ?? true,
    );
  }

  @override
  Future<void> saveSettings(NotificationSettings settings) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyNotificationsEnabled, settings.notificationsEnabled);
    await prefs.setInt(_keyReminderHour, settings.reminderHour);
    await prefs.setInt(_keyReminderMinute, settings.reminderMinute);
    await prefs.setInt(_keyDaysBefore, settings.daysBefore);
    await prefs.setBool(_keyDigestEnabled, settings.digestEnabled);
  }
}

