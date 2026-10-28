import 'package:equatable/equatable.dart';

/// Represents a notification scheduled to be delivered at a specific future time.
/// Pure Dart class with no framework or plugin dependencies.
class PlannedNotification extends Equatable {
  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledDate,
    this.payload,
  });

  /// Stable, deterministic notification identifier.
  final int id;

  /// Display title of the notification.
  final String title;

  /// Body text explaining what is expiring.
  final String body;

  /// Target wall-clock time when the notification should fire.
  final DateTime scheduledDate;

  /// Optional deep-link payload (e.g. 'item:42' or 'digest:expiring_soon').
  final String? payload;

  @override
  List<Object?> get props => [id, title, body, scheduledDate, payload];
}

