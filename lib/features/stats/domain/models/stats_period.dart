/// Time windows supported by the waste statistics dashboard.
enum StatsPeriod {
  last7Days('Last 7 days', '7d'),
  last30Days('Last 30 days', '30d'),
  last90Days('Last 90 days', '90d'),
  allTime('All time', 'all');

  const StatsPeriod(this.label, this.storageKey);

  final String label;
  final String storageKey;

  static StatsPeriod fromStorageKey(String? key) {
    return StatsPeriod.values.firstWhere(
      (p) => p.storageKey == key,
      orElse: () => StatsPeriod.last30Days,
    );
  }

  /// Computes the start of the period in local time relative to [now].
  ///
  /// For fixed day counts (7, 30, 90), starts at 00:00:00.000 local time
  /// N-1 calendar days before [now].
  /// For [allTime], returns the epoch start (DateTime.fromMillisecondsSinceEpoch(0)).
  DateTime getStartDate(DateTime now) {
    final localNow = now.toLocal();

    switch (this) {
      case StatsPeriod.last7Days:
        return DateTime(localNow.year, localNow.month, localNow.day - 6);
      case StatsPeriod.last30Days:
        return DateTime(localNow.year, localNow.month, localNow.day - 29);
      case StatsPeriod.last90Days:
        return DateTime(localNow.year, localNow.month, localNow.day - 89);
      case StatsPeriod.allTime:
        return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// End of the evaluation period (end of [now]'s calendar day in local time).
  DateTime getEndDate(DateTime now) {
    final localNow = now.toLocal();
    return DateTime(localNow.year, localNow.month, localNow.day, 23, 59, 59, 999);
  }
}
