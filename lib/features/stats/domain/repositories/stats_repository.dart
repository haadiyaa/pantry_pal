import '../../../inventory/domain/models/pantry_event.dart';
import '../models/stats_raw_data.dart';

/// Contract for fetching aggregate waste statistics from the data layer.
/// Blocs and UI depend strictly on this interface.
abstract class StatsRepository {
  /// Aggregates and retrieves event records between [start] and [end] inclusive.
  /// Strictly filters out events where reason == 'deleted'.
  Future<StatsRawData> getStatsData({
    required DateTime start,
    required DateTime end,
  });

  /// Inserts developer sample events in debug builds.
  Future<void> insertSampleEvents(List<PantryEvent> events);

  /// Clears developer sample events without touching real user data.
  Future<int> clearSampleEvents();
}

