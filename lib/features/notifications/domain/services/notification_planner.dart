import '../../../inventory/domain/models/pantry_item.dart';
import '../models/notification_settings.dart';
import '../models/planned_notification.dart';

/// Pure functional planning service for all local notifications.
/// Has zero Flutter framework, UI, or plugin dependencies.
class NotificationPlanner {
  const NotificationPlanner({this.maxNotifications = 50});

  /// Maximum notifications scheduled at any time to respect iOS (64) and Android platform caps.
  final int maxNotifications;

  /// Prefix ranges for deterministic IDs (positive 31-bit integers):
  /// - Per-item N days before: 1_000_000 + (itemId * 10) + 1
  /// - Per-item expiry day:    1_000_000 + (itemId * 10) + 2
  /// - Daily digest day 0-6:   2_000_000 + dayOffset
  /// - Test notification:      999_999
  static const int _itemNotificationBase = 1000000;
  static const int _digestNotificationBase = 2000000;
  static const int testNotificationId = 999999;

  /// Computes a list of [PlannedNotification]s from the current [items], user [settings],
  /// and the evaluation timestamp [now].
  List<PlannedNotification> plan({
    required List<PantryItem> items,
    required NotificationSettings settings,
    required DateTime now,
  }) {
    if (!settings.notificationsEnabled) {
      return const [];
    }

    final planned = <PlannedNotification>[];

    // 1. Plan Per-Item Reminders
    for (final item in items) {
      if (item.id == null) continue;

      final expiryDay = DateTime(
        item.expiryDate.year,
        item.expiryDate.month,
        item.expiryDate.day,
      );

      // (a) N days before expiry
      final nDaysBeforeDate = expiryDay.subtract(Duration(days: settings.daysBefore));
      final nDaysBeforeSchedule = DateTime(
        nDaysBeforeDate.year,
        nDaysBeforeDate.month,
        nDaysBeforeDate.day,
        settings.reminderHour,
        settings.reminderMinute,
      );

      if (nDaysBeforeSchedule.isAfter(now)) {
        final bodyText = settings.daysBefore == 1
            ? '${item.name} expires tomorrow'
            : '${item.name} expires in ${settings.daysBefore} days';

        planned.add(
          PlannedNotification(
            id: _itemNotificationBase + (item.id! * 10) + 1,
            title: 'Expiry Reminder',
            body: bodyText,
            scheduledDate: nDaysBeforeSchedule,
            payload: 'item:${item.id}',
          ),
        );
      }

      // (b) On the day of expiry
      final expiryDaySchedule = DateTime(
        expiryDay.year,
        expiryDay.month,
        expiryDay.day,
        settings.reminderHour,
        settings.reminderMinute,
      );

      if (expiryDaySchedule.isAfter(now)) {
        planned.add(
          PlannedNotification(
            id: _itemNotificationBase + (item.id! * 10) + 2,
            title: 'Expiry Alert',
            body: '${item.name} expires today',
            scheduledDate: expiryDaySchedule,
            payload: 'item:${item.id}',
          ),
        );
      }
    }

    // 2. Plan Daily "Use These First" Digests (next 7 days)
    if (settings.digestEnabled) {
      final todayDate = DateTime(now.year, now.month, now.day);

      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        final targetDate = todayDate.add(Duration(days: dayOffset));
        final triggerTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          settings.reminderHour,
          settings.reminderMinute,
        );

        // Skip if trigger time has already elapsed
        if (!triggerTime.isAfter(now)) continue;

        // Items expiring within the next 3 days relative to targetDate:
        // targetDate <= itemExpiryDay <= targetDate + 3 days
        final windowEnd = targetDate.add(const Duration(days: 3));

        final expiringItems = items.where((item) {
          final itemDay = DateTime(
            item.expiryDate.year,
            item.expiryDate.month,
            item.expiryDate.day,
          );
          return !itemDay.isBefore(targetDate) && !itemDay.isAfter(windowEnd);
        }).toList();

        if (expiringItems.isEmpty) {
          continue; // Nothing expiring: skip digest for this day
        }

        // Sort by expiry date ASC, then name ASC
        expiringItems.sort((a, b) {
          final cmp = a.expiryDate.compareTo(b.expiryDate);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });

        final bodyText = _buildDigestBody(expiringItems);

        planned.add(
          PlannedNotification(
            id: _digestNotificationBase + dayOffset,
            title: 'Use These First',
            body: bodyText,
            scheduledDate: triggerTime,
            payload: 'digest:expiring_soon',
          ),
        );
      }
    }

    // 3. Sort chronologically by scheduledDate
    planned.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    // 4. Cap total notifications to maxNotifications limit
    if (planned.length > maxNotifications) {
      return planned.sublist(0, maxNotifications);
    }

    return planned;
  }

  static String _buildDigestBody(List<PantryItem> items) {
    final count = items.length;
    final itemWord = count == 1 ? '1 item needs' : '$count items need';

    if (count == 1) {
      return '$itemWord attention: ${items[0].name}';
    } else if (count == 2) {
      return '$itemWord attention: ${items[0].name}, ${items[1].name}';
    } else if (count == 3) {
      return '$itemWord attention: ${items[0].name}, ${items[1].name}, ${items[2].name}';
    } else {
      final firstThree = '${items[0].name}, ${items[1].name}, ${items[2].name}';
      final remaining = count - 3;
      return '$itemWord attention: $firstThree +$remaining more';
    }
  }
}

