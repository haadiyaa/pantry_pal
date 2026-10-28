import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/planned_notification.dart';
import '../../domain/repositories/notification_settings_repository.dart';
import '../../domain/services/notification_scheduler.dart';
import '../../domain/services/notification_sync_service.dart';
import 'notification_settings_state.dart';

class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  NotificationSettingsCubit({
    required this.settingsRepository,
    required this.scheduler,
    required this.syncService,
  }) : super(const NotificationSettingsState());

  final NotificationSettingsRepository settingsRepository;
  final NotificationScheduler scheduler;
  final NotificationSyncService syncService;

  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true));
    try {
      final settings = await settingsRepository.loadSettings();
      final hasPermission = await scheduler.checkPermission();

      emit(state.copyWith(
        settings: settings,
        permissionStatus: hasPermission
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.initial,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: () => e.toString(),
      ));
    }
  }

  Future<void> toggleNotifications(bool enable) async {
    if (enable) {
      final granted = await scheduler.requestPermission();
      if (!granted) {
        emit(state.copyWith(
          permissionStatus: NotificationPermissionStatus.denied,
          settings: state.settings.copyWith(notificationsEnabled: false),
        ));
        await settingsRepository.saveSettings(
          state.settings.copyWith(notificationsEnabled: false),
        );
        return;
      }

      final updated = state.settings.copyWith(notificationsEnabled: true);
      emit(state.copyWith(
        settings: updated,
        permissionStatus: NotificationPermissionStatus.granted,
      ));
      await settingsRepository.saveSettings(updated);
      await syncService.syncNotifications();
    } else {
      final updated = state.settings.copyWith(notificationsEnabled: false);
      emit(state.copyWith(settings: updated));
      await settingsRepository.saveSettings(updated);
      await scheduler.cancelAll();
    }
  }

  Future<void> updateReminderTime(int hour, int minute) async {
    final updated = state.settings.copyWith(
      reminderHour: hour,
      reminderMinute: minute,
    );
    emit(state.copyWith(settings: updated));
    await settingsRepository.saveSettings(updated);
    if (updated.notificationsEnabled) {
      await syncService.syncNotifications();
    }
  }

  Future<void> updateDaysBefore(int days) async {
    final updated = state.settings.copyWith(daysBefore: days.clamp(1, 7));
    emit(state.copyWith(settings: updated));
    await settingsRepository.saveSettings(updated);
    if (updated.notificationsEnabled) {
      await syncService.syncNotifications();
    }
  }

  Future<void> toggleDigest(bool enable) async {
    final updated = state.settings.copyWith(digestEnabled: enable);
    emit(state.copyWith(settings: updated));
    await settingsRepository.saveSettings(updated);
    if (updated.notificationsEnabled) {
      await syncService.syncNotifications();
    }
  }

  Future<void> sendTestNotification() async {
    try {
      final testNotification = PlannedNotification(
        id: 999999,
        title: 'Pantry Pal Test Alert',
        body: 'Expiry reminders are active! Items will alert at ${state.settings.reminderHour.toString().padLeft(2, '0')}:${state.settings.reminderMinute.toString().padLeft(2, '0')}.',
        scheduledDate: DateTime.now(),
        payload: 'digest:expiring_soon',
      );

      await scheduler.showTestNotification(testNotification);
      emit(state.copyWith(testNotificationSent: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: () => 'Failed to send test notification: $e'));
    }
  }

  Future<void> scheduleOneMinuteTestReminder() async {
    try {
      final targetTime = DateTime.now().add(const Duration(minutes: 1));
      final testNotification = PlannedNotification(
        id: 999998,
        title: 'Expiry Alert (Scheduled Test)',
        body: 'Scheduled reminder succeeded! Alarms and background delivery are working on your device.',
        scheduledDate: targetTime,
        payload: 'digest:expiring_soon',
      );

      await scheduler.scheduleSingle(testNotification);
      emit(state.copyWith(testNotificationSent: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: () => 'Failed to schedule test reminder: $e'));
    }
  }

  void resetTestNotificationSent() {
    emit(state.copyWith(testNotificationSent: false));
  }
}
