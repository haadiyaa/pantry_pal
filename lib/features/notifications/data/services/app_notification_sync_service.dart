import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../domain/repositories/notification_settings_repository.dart';
import '../../domain/services/notification_planner.dart';
import '../../domain/services/notification_scheduler.dart';
import '../../domain/services/notification_sync_service.dart';

class AppNotificationSyncService implements NotificationSyncService {
  const AppNotificationSyncService({
    required this.pantryRepository,
    required this.settingsRepository,
    required this.scheduler,
    this.planner = const NotificationPlanner(),
  });

  final PantryRepository pantryRepository;
  final NotificationSettingsRepository settingsRepository;
  final NotificationScheduler scheduler;
  final NotificationPlanner planner;

  @override
  Future<void> syncNotifications() async {
    final settings = await settingsRepository.loadSettings();

    if (!settings.notificationsEnabled) {
      await scheduler.cancelAll();
      return;
    }

    final items = await pantryRepository.search();
    final planned = planner.plan(
      items: items,
      settings: settings,
      now: DateTime.now(),
    );

    await scheduler.schedule(planned);
  }
}

