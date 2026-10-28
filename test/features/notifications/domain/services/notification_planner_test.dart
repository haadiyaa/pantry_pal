import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/notifications/domain/models/notification_settings.dart';
import 'package:pantry_pal/features/notifications/domain/services/notification_planner.dart';

void main() {
  late NotificationPlanner planner;

  setUp(() {
    planner = const NotificationPlanner(maxNotifications: 50);
  });

  group('NotificationPlanner', () {
    final fixedNowMorning = DateTime(2026, 10, 28, 8, 0); // 8:00 AM
    final fixedNowAfternoon = DateTime(2026, 10, 28, 14, 0); // 2:00 PM

    const defaultSettings = NotificationSettings(
      notificationsEnabled: true,
      reminderHour: 9,
      reminderMinute: 0,
      daysBefore: 2,
      digestEnabled: true,
    );

    test('returns empty list when notifications are disabled in settings', () {
      final items = [
        PantryItem(
          id: 1,
          name: 'Fresh Milk',
          expiryDate: DateTime(2026, 10, 30),
          addedAt: DateTime(2026, 10, 20),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(notificationsEnabled: false),
        now: fixedNowMorning,
      );

      expect(result, isEmpty);
    });

    test('item expiring tomorrow schedules reminder tomorrow morning', () {
      final items = [
        PantryItem(
          id: 1,
          name: 'Whole Milk',
          expiryDate: DateTime(2026, 10, 29, 15, 30),
          addedAt: DateTime(2026, 10, 20),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(digestEnabled: false),
        now: fixedNowAfternoon, // 2:00 PM on Oct 28
      );

      // Expiry is Oct 29. 2 days before is Oct 27 (past).
      // Day of expiry reminder is Oct 29 09:00 AM (future).
      expect(result.length, 1);
      final reminder = result.first;
      expect(reminder.title, 'Expiry Alert');
      expect(reminder.body, 'Whole Milk expires today');
      expect(reminder.scheduledDate, DateTime(2026, 10, 29, 9, 0));
      expect(reminder.payload, 'item:1');
    });

    test('item expiring today schedules alert today if reminder time is in future', () {
      final items = [
        PantryItem(
          id: 2,
          name: 'Eggs',
          expiryDate: DateTime(2026, 10, 28, 23, 59),
          addedAt: DateTime(2026, 10, 20),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(digestEnabled: false),
        now: fixedNowMorning, // 8:00 AM, before 9:00 AM
      );

      expect(result.length, 1);
      expect(result.first.title, 'Expiry Alert');
      expect(result.first.body, 'Eggs expires today');
      expect(result.first.scheduledDate, DateTime(2026, 10, 28, 9, 0));
    });

    test('already expired item does not schedule any reminder', () {
      final items = [
        PantryItem(
          id: 3,
          name: 'Old Bread',
          expiryDate: DateTime(2026, 10, 25),
          addedAt: DateTime(2026, 10, 15),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(digestEnabled: false),
        now: fixedNowAfternoon,
      );

      expect(result, isEmpty);
    });

    test('reminder time already passed today is not scheduled', () {
      final items = [
        PantryItem(
          id: 4,
          name: 'Yogurt',
          expiryDate: DateTime(2026, 10, 28, 12, 0),
          addedAt: DateTime(2026, 10, 20),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(digestEnabled: false),
        now: fixedNowAfternoon, // 2:00 PM > 9:00 AM
      );

      expect(result, isEmpty);
    });

    test('daysBefore edge cases: 1 day before formats as "tomorrow"', () {
      final items = [
        PantryItem(
          id: 5,
          name: 'Cheddar Cheese',
          expiryDate: DateTime(2026, 10, 30),
          addedAt: DateTime(2026, 10, 20),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(
          daysBefore: 1,
          digestEnabled: false,
        ),
        now: fixedNowMorning, // Oct 28 8am
      );

      // 1 day before Oct 30 is Oct 29 at 9am
      final advanceReminder = result.firstWhere((n) => n.title == 'Expiry Reminder');
      expect(advanceReminder.body, 'Cheddar Cheese expires tomorrow');
      expect(advanceReminder.scheduledDate, DateTime(2026, 10, 29, 9, 0));
    });

    test('daysBefore edge cases: 7 days before schedules 7 days in advance', () {
      final items = [
        PantryItem(
          id: 6,
          name: 'Canned Beans',
          expiryDate: DateTime(2026, 11, 4),
          addedAt: DateTime(2026, 10, 20),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(
          daysBefore: 7,
          digestEnabled: false,
        ),
        now: fixedNowMorning, // Oct 28 8am
      );

      // 7 days before Nov 4 is Oct 28 at 9am
      final advanceReminder = result.firstWhere((n) => n.title == 'Expiry Reminder');
      expect(advanceReminder.body, 'Canned Beans expires in 7 days');
      expect(advanceReminder.scheduledDate, DateTime(2026, 10, 28, 9, 0));
    });

    test('digest is skipped when no items are expiring within 3 days', () {
      final items = [
        PantryItem(
          id: 7,
          name: 'Pasta',
          expiryDate: DateTime(2026, 12, 1),
          addedAt: DateTime(2026, 10, 20),
        ),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(digestEnabled: true),
        now: fixedNowMorning,
      );

      // Per-item reminders are far in the future, digests for next 7 days should be empty
      final digests = result.where((n) => n.title == 'Use These First');
      expect(digests, isEmpty);
    });

    test('digest content lists items correctly for 1, 2, 3, and >3 items', () {
      final items = [
        PantryItem(id: 1, name: 'Milk', expiryDate: DateTime(2026, 10, 29), addedAt: DateTime(2026, 10, 20)),
        PantryItem(id: 2, name: 'Cheese', expiryDate: DateTime(2026, 10, 29), addedAt: DateTime(2026, 10, 20)),
        PantryItem(id: 3, name: 'Bread', expiryDate: DateTime(2026, 10, 30), addedAt: DateTime(2026, 10, 20)),
        PantryItem(id: 4, name: 'Apples', expiryDate: DateTime(2026, 10, 30), addedAt: DateTime(2026, 10, 20)),
      ];

      final result = planner.plan(
        items: items,
        settings: defaultSettings.copyWith(digestEnabled: true),
        now: fixedNowMorning, // Oct 28 8:00 AM
      );

      // Digest for today (Oct 28 9:00 AM) captures all 4 items expiring within 3 days
      final todayDigest = result.firstWhere(
        (n) => n.title == 'Use These First' && n.scheduledDate == DateTime(2026, 10, 28, 9, 0),
      );

      expect(todayDigest.body, contains('4 items need attention:'));
      expect(todayDigest.body, contains('+1 more'));
      expect(todayDigest.payload, 'digest:expiring_soon');
    });

    test('caps total notifications to maxNotifications limit', () {
      const cappedPlanner = NotificationPlanner(maxNotifications: 5);

      final items = List.generate(
        15,
        (i) => PantryItem(
          id: i + 1,
          name: 'Item $i',
          expiryDate: DateTime(2026, 10, 30).add(Duration(days: i)),
          addedAt: DateTime(2026, 10, 20),
        ),
      );

      final result = cappedPlanner.plan(
        items: items,
        settings: defaultSettings,
        now: fixedNowMorning,
      );

      expect(result.length, 5);
      // Ensure sorted chronologically
      for (var i = 0; i < result.length - 1; i++) {
        expect(result[i].scheduledDate.isBefore(result[i + 1].scheduledDate) ||
            result[i].scheduledDate.isAtSameMomentAs(result[i + 1].scheduledDate), isTrue);
      }
    });

    test('generates stable, deterministic IDs', () {
      final item = PantryItem(
        id: 42,
        name: 'Organic Milk',
        expiryDate: DateTime(2026, 10, 31),
        addedAt: DateTime(2026, 10, 20),
      );

      final run1 = planner.plan(
        items: [item],
        settings: defaultSettings.copyWith(digestEnabled: false),
        now: fixedNowMorning,
      );

      final run2 = planner.plan(
        items: [item],
        settings: defaultSettings.copyWith(digestEnabled: false),
        now: fixedNowMorning,
      );

      expect(run1.map((n) => n.id).toList(), run2.map((n) => n.id).toList());
      // ID for 2 days before: 1_000_000 + (42 * 10) + 1 = 1_000_421
      expect(run1.any((n) => n.id == 1000421), isTrue);
      // ID for expiry day: 1_000_000 + (42 * 10) + 2 = 1_000_422
      expect(run1.any((n) => n.id == 1000422), isTrue);
    });

    test('handles date-boundary case: item expiring just after midnight', () {
      // Item expires at 00:01 AM on Oct 29
      final item = PantryItem(
        id: 99,
        name: 'Midnight Milk',
        expiryDate: DateTime(2026, 10, 29, 0, 1),
        addedAt: DateTime(2026, 10, 20),
      );

      final result = planner.plan(
        items: [item],
        settings: defaultSettings.copyWith(digestEnabled: false),
        now: fixedNowMorning, // Oct 28 8:00 AM
      );

      // Expiry day reminder must be Oct 29 at 9:00 AM
      final expiryReminder = result.firstWhere((n) => n.title == 'Expiry Alert');
      expect(expiryReminder.scheduledDate, DateTime(2026, 10, 29, 9, 0));

      // Advance reminder (2 days before Oct 29) is Oct 27 9:00 AM (past, so not scheduled)
      expect(result.length, 1);
    });
  });
}

