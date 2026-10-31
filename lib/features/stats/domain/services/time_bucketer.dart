import '../../../inventory/domain/models/pantry_event_reason.dart';
import '../models/stats_period.dart';
import '../models/stats_raw_data.dart';
import '../models/time_bucket.dart';

/// Pure functional service generating continuous chronological buckets for Chart 1.
///
/// Rules:
/// - Uses device's local time zone.
/// - Weeks strictly start on Monday.
/// - 7 days -> daily buckets (7 buckets).
/// - 30 days & 90 days -> weekly buckets (Monday-Sunday).
/// - All time -> monthly buckets (earliest event to now).
/// - Missing buckets are populated with zero counts to keep the axis continuous.
/// - Zero Flutter framework or plugin imports.
class TimeBucketer {
  const TimeBucketer();

  /// Builds the complete list of continuous buckets populated with event counts.
  List<TimeBucket> buildBuckets({
    required StatsPeriod period,
    required DateTime now,
    required List<EventDetailRecord> events,
    DateTime? earliestEventDate,
  }) {
    final localNow = now.toLocal();
    final todayMidnight = DateTime(localNow.year, localNow.month, localNow.day);

    final List<TimeBucket> emptyBuckets;

    switch (period) {
      case StatsPeriod.last7Days:
        emptyBuckets = _generateDailyBuckets(
          startDate: DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 6),
          daysCount: 7,
        );
      case StatsPeriod.last30Days:
        emptyBuckets = _generateWeeklyBuckets(
          rangeStart: DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 29),
          rangeEnd: localNow,
        );
      case StatsPeriod.last90Days:
        emptyBuckets = _generateWeeklyBuckets(
          rangeStart: DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 89),
          rangeEnd: localNow,
        );
      case StatsPeriod.allTime:
        final start = earliestEventDate?.toLocal() ?? todayMidnight;
        emptyBuckets = _generateMonthlyBuckets(
          earliestDate: start,
          now: localNow,
        );
    }

    if (emptyBuckets.isEmpty) return const [];

    // Tally event units into buckets
    final bucketCounts = <int, _BucketTally>{};
    for (var i = 0; i < emptyBuckets.length; i++) {
      bucketCounts[i] = _BucketTally();
    }

    for (final event in events) {
      // Deleted events are strictly excluded
      if (event.reason == PantryEventReason.deleted) continue;

      final eventLocal = event.occurredAt.toLocal();

      for (var i = 0; i < emptyBuckets.length; i++) {
        final bucket = emptyBuckets[i];
        final isInBucket = (eventLocal.isAfter(bucket.start) ||
                eventLocal.isAtSameMomentAs(bucket.start)) &&
            (eventLocal.isBefore(bucket.end) ||
                eventLocal.isAtSameMomentAs(bucket.end));

        if (isInBucket) {
          final tally = bucketCounts[i]!;
          if (event.reason == PantryEventReason.used) {
            tally.used += event.quantity;
          } else if (event.reason == PantryEventReason.wasted) {
            tally.wasted += event.quantity;
          }
          break;
        }
      }
    }

    return List.generate(emptyBuckets.length, (i) {
      final base = emptyBuckets[i];
      final tally = bucketCounts[i]!;
      return base.copyWith(
        usedCount: tally.used,
        wastedCount: tally.wasted,
      );
    });
  }

  /// Generates consecutive daily buckets.
  List<TimeBucket> _generateDailyBuckets({
    required DateTime startDate,
    required int daysCount,
  }) {
    final buckets = <TimeBucket>[];
    for (var i = 0; i < daysCount; i++) {
      final dayStart = DateTime(startDate.year, startDate.month, startDate.day + i);
      final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day, 23, 59, 59, 999);
      final label = _formatDayLabel(dayStart);
      buckets.add(
        TimeBucket(
          start: dayStart,
          end: dayEnd,
          label: label,
        ),
      );
    }
    return buckets;
  }

  /// Generates consecutive weekly buckets aligned with Monday week starts.
  List<TimeBucket> _generateWeeklyBuckets({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    // Determine the Monday of the week containing rangeStart
    // DateTime weekday: Monday = 1, Sunday = 7
    final firstMonday = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day - (rangeStart.weekday - 1),
    );

    // Determine the Monday of the week containing rangeEnd
    final lastMonday = DateTime(
      rangeEnd.year,
      rangeEnd.month,
      rangeEnd.day - (rangeEnd.weekday - 1),
    );

    final buckets = <TimeBucket>[];
    var currentMonday = firstMonday;

    while (currentMonday.isBefore(lastMonday) ||
        currentMonday.isAtSameMomentAs(lastMonday)) {
      final weekEnd = DateTime(
        currentMonday.year,
        currentMonday.month,
        currentMonday.day + 6,
        23,
        59,
        59,
        999,
      );

      final label = _formatWeekLabel(currentMonday, weekEnd);

      buckets.add(
        TimeBucket(
          start: currentMonday,
          end: weekEnd,
          label: label,
        ),
      );

      // Advance by exactly 7 calendar days to cleanly cross month/leap-day boundaries
      currentMonday = DateTime(
        currentMonday.year,
        currentMonday.month,
        currentMonday.day + 7,
      );
    }

    return buckets;
  }

  /// Generates consecutive monthly buckets from [earliestDate] to [now].
  List<TimeBucket> _generateMonthlyBuckets({
    required DateTime earliestDate,
    required DateTime now,
  }) {
    var currentMonthStart = DateTime(earliestDate.year, earliestDate.month, 1);
    final targetMonthStart = DateTime(now.year, now.month, 1);

    final buckets = <TimeBucket>[];

    while (currentMonthStart.isBefore(targetMonthStart) ||
        currentMonthStart.isAtSameMomentAs(targetMonthStart)) {
      // Day 0 of next month is the last calendar day of the current month
      final monthEnd = DateTime(
        currentMonthStart.year,
        currentMonthStart.month + 1,
        0,
        23,
        59,
        59,
        999,
      );

      final label = _formatMonthLabel(currentMonthStart);

      buckets.add(
        TimeBucket(
          start: currentMonthStart,
          end: monthEnd,
          label: label,
        ),
      );

      // Advance by 1 month
      currentMonthStart = DateTime(
        currentMonthStart.year,
        currentMonthStart.month + 1,
        1,
      );
    }

    return buckets;
  }

  String _formatDayLabel(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdayStr = days[date.weekday - 1];
    return '$weekdayStr ${date.day}';
  }

  String _formatWeekLabel(DateTime start, DateTime end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final startMonth = months[start.month - 1];
    final endMonth = months[end.month - 1];

    if (start.month == end.month) {
      return '$startMonth ${start.day}-${end.day}';
    }
    return '$startMonth ${start.day}-$endMonth ${end.day}';
  }

  String _formatMonthLabel(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year.toString().substring(2)}';
  }
}

class _BucketTally {
  int used = 0;
  int wasted = 0;
}

