import 'package:equatable/equatable.dart';

/// Represents a single chronological bucket for Chart 1 (used vs wasted over time).
/// Guaranteed continuous by [TimeBucketer] with zeros for missing periods.
class TimeBucket extends Equatable {
  const TimeBucket({
    required this.start,
    required this.end,
    required this.label,
    this.usedCount = 0,
    this.wastedCount = 0,
  });

  final DateTime start;
  final DateTime end;
  final String label;
  final int usedCount;
  final int wastedCount;

  int get totalUnits => usedCount + wastedCount;

  TimeBucket copyWith({
    DateTime? start,
    DateTime? end,
    String? label,
    int? usedCount,
    int? wastedCount,
  }) {
    return TimeBucket(
      start: start ?? this.start,
      end: end ?? this.end,
      label: label ?? this.label,
      usedCount: usedCount ?? this.usedCount,
      wastedCount: wastedCount ?? this.wastedCount,
    );
  }

  @override
  List<Object?> get props => [start, end, label, usedCount, wastedCount];
}

