import '../models/planned_notification.dart';

/// Contract for scheduling and presenting platform notifications.
abstract interface class NotificationScheduler {
  /// Initializes the local notifications plugin and notification tap listener.
  Future<void> init({required void Function(String? payload) onNotificationTap});

  /// Prompts the system permission dialog for notifications.
  /// Returns `true` if permission is granted.
  Future<bool> requestPermission();

  /// Checks whether notifications are currently allowed.
  Future<bool> checkPermission();

  /// Cancels all pending notifications across the application.
  Future<void> cancelAll();

  /// Schedules a list of [PlannedNotification]s using inexact idle-wake alarms.
  Future<void> schedule(List<PlannedNotification> notifications);

  /// Schedules a single notification without canceling others.
  Future<void> scheduleSingle(PlannedNotification notification);

  /// Shows an immediate test notification to verify audio/visual alerts.
  Future<void> showTestNotification(PlannedNotification notification);

  /// Returns the payload if the application was cold-launched by tapping a notification.
  Future<String?> getLaunchPayload();
}

