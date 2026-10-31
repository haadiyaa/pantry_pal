import 'package:equatable/equatable.dart';

import '../../domain/models/stats_period.dart';
import '../../domain/models/stats_summary.dart';

enum StatsStatus { initial, loading, success, failure }

class StatsState extends Equatable {
  const StatsState({
    this.status = StatsStatus.initial,
    this.period = StatsPeriod.last30Days,
    this.summary,
    this.errorMessage,
    this.actionMessage,
  });

  final StatsStatus status;
  final StatsPeriod period;
  final StatsSummary? summary;
  final String? errorMessage;
  final String? actionMessage;

  StatsState copyWith({
    StatsStatus? status,
    StatsPeriod? period,
    StatsSummary? Function()? summary,
    String? Function()? errorMessage,
    String? Function()? actionMessage,
  }) {
    return StatsState(
      status: status ?? this.status,
      period: period ?? this.period,
      summary: summary != null ? summary() : this.summary,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      actionMessage: actionMessage != null ? actionMessage() : this.actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, period, summary, errorMessage, actionMessage];
}

