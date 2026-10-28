import 'package:equatable/equatable.dart';

/// User preferences for expiry alerts and daily digests.
class NotificationSettings extends Equatable {
  const NotificationSettings({
    this.notificationsEnabled = false,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.daysBefore = 2,
    this.digestEnabled = true,
  });

  /// Master switch for all scheduled notifications.
  final bool notificationsEnabled;

  /// Hour of the day (0-23) when reminders and digests fire.
  final int reminderHour;

  /// Minute of the hour (0-59) when reminders and digests fire.
  final int reminderMinute;

  /// Number of days before item expiry to send the first reminder (1 to 7).
  final int daysBefore;

  /// Whether to schedule daily "Use these first" digests.
  final bool digestEnabled;

  NotificationSettings copyWith({
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
    int? daysBefore,
    bool? digestEnabled,
  }) {
    return NotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      daysBefore: daysBefore ?? this.daysBefore,
      digestEnabled: digestEnabled ?? this.digestEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifications_enabled': notificationsEnabled,
      'reminder_hour': reminderHour,
      'reminder_minute': reminderMinute,
      'days_before': daysBefore,
      'digest_enabled': digestEnabled,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      notificationsEnabled: map['notifications_enabled'] as bool? ?? false,
      reminderHour: map['reminder_hour'] as int? ?? 9,
      reminderMinute: map['reminder_minute'] as int? ?? 0,
      daysBefore: (map['days_before'] as int? ?? 2).clamp(1, 7),
      digestEnabled: map['digest_enabled'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [
        notificationsEnabled,
        reminderHour,
        reminderMinute,
        daysBefore,
        digestEnabled,
      ];
}

