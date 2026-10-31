import '../models/stats_period.dart';

/// Interface for persisting the user's selected statistics time period.
abstract class StatsPeriodRepository {
  /// Gets the persisted [StatsPeriod], defaulting to [StatsPeriod.last30Days] if unset.
  Future<StatsPeriod> getSelectedPeriod();

  /// Persists the selected [StatsPeriod].
  Future<void> setSelectedPeriod(StatsPeriod period);
}

