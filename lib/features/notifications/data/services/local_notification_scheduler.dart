import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/planned_notification.dart';
import '../../domain/services/notification_scheduler.dart';

class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'pantry_pal_expiry_channel';
  static const String channelName = 'Pantry Expiry Reminders';
  static const String channelDescription =
      'Alerts for upcoming expiry dates and daily pantry digests';

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  @override
  Future<void> init({required void Function(String? payload) onNotificationTap}) async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap(response.payload);
      },
    );
  }

  @override
  Future<bool> requestPermission() async {
    // 1. Try platform-specific implementations
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      if (granted != null) return granted;
    }

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted != null) return granted;
    }

    // 2. Fallback to permission_handler
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Future<bool> checkPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  @override
  Future<void> schedule(List<PlannedNotification> notifications) async {
    // Cancel all existing scheduled alarms before reprogramming the updated plan
    await cancelAll();

    final nowTz = tz.TZDateTime.now(tz.local);

    for (final item in notifications) {
      final scheduledTz = tz.TZDateTime.from(item.scheduledDate, tz.local);

      // Guard: only schedule future dates
      if (!scheduledTz.isAfter(nowTz)) continue;

      try {
        await _plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: scheduledTz,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: item.payload,
        );
      } catch (e) {
        debugPrint('Failed to schedule notification ${item.id}: $e');
      }
    }
  }

  @override
  Future<void> showTestNotification(PlannedNotification notification) async {
    await _plugin.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      notificationDetails: _notificationDetails,
      payload: notification.payload,
    );
  }

  @override
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }
}

