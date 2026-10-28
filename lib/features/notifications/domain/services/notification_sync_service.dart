/// Interface for synchronizing inventory items and user settings into scheduled notifications.
abstract interface class NotificationSyncService {
  Future<void> syncNotifications();
}

