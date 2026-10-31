import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/stats_period.dart';
import '../../domain/repositories/stats_period_repository.dart';
import '../../domain/repositories/stats_repository.dart';
import '../../domain/services/stats_calculator.dart';
import '../../domain/services/stats_sample_data_generator.dart';
import 'stats_state.dart';

/// Cubit managing statistics calculation, time period selection, and sample seeding.
class StatsCubit extends Cubit<StatsState> {
  StatsCubit({
    required this.statsRepository,
    required this.periodRepository,
    StatsCalculator? statsCalculator,
    StatsSampleDataGenerator? sampleGenerator,
    DateTime Function()? nowProvider,
  })  : _statsCalculator = statsCalculator ?? const StatsCalculator(),
        _sampleGenerator = sampleGenerator ?? const StatsSampleDataGenerator(),
        _nowProvider = nowProvider ?? DateTime.now,
        super(const StatsState());

  final StatsRepository statsRepository;
  final StatsPeriodRepository periodRepository;
  final StatsCalculator _statsCalculator;
  final StatsSampleDataGenerator _sampleGenerator;
  final DateTime Function() _nowProvider;

  int _currentRequestId = 0;

  /// Initializes the cubit by restoring the persisted [StatsPeriod] and loading stats.
  Future<void> init() async {
    final savedPeriod = await periodRepository.getSelectedPeriod();
    await _loadForPeriod(savedPeriod);
  }

  /// Switches the active time period and triggers aggregation.
  Future<void> changePeriod(StatsPeriod period) async {
    if (state.period == period && state.status == StatsStatus.success) {
      return;
    }
    await periodRepository.setSelectedPeriod(period);
    await _loadForPeriod(period);
  }

  /// Re-runs the aggregation for the current period (e.g. pull-to-refresh or revisit).
  Future<void> refresh() async {
    await _loadForPeriod(state.period);
  }

  /// Seeds 4 months of realistic debug sample data and re-runs aggregation.
  Future<void> insertSampleData() async {
    try {
      final now = _nowProvider();
      final events = _sampleGenerator.generateSampleEvents(now);
      if (events.isNotEmpty) {
        await statsRepository.insertSampleEvents(events);
        emit(
          state.copyWith(
            actionMessage: () => 'Inserted 4 months of sample data',
          ),
        );
      }
      await refresh();
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: () => 'Failed to insert sample data: $e',
        ),
      );
    }
  }

  /// Clears developer sample data without affecting real user data.
  Future<void> clearSampleData() async {
    try {
      final cleared = await statsRepository.clearSampleEvents();
      emit(
        state.copyWith(
          actionMessage: () => 'Cleared $cleared sample records',
        ),
      );
      await refresh();
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: () => 'Failed to clear sample data: $e',
        ),
      );
    }
  }

  /// Clears any transient feedback banner/message.
  void clearActionMessage() {
    emit(state.copyWith(actionMessage: () => null));
  }

  Future<void> _loadForPeriod(StatsPeriod period) async {
    final requestId = ++_currentRequestId;
    emit(state.copyWith(status: StatsStatus.loading, period: period));

    try {
      final now = _nowProvider();
      final start = period.getStartDate(now);
      final end = period.getEndDate(now);

      final rawData = await statsRepository.getStatsData(start: start, end: end);
      if (requestId != _currentRequestId || isClosed) return;

      final summary = _statsCalculator.calculate(
        rawData: rawData,
        period: period,
        now: now,
      );
      if (requestId != _currentRequestId || isClosed) return;

      emit(
        state.copyWith(
          status: StatsStatus.success,
          period: period,
          summary: () => summary,
          errorMessage: () => null,
        ),
      );
    } catch (e) {
      if (requestId != _currentRequestId || isClosed) return;
      emit(
        state.copyWith(
          status: StatsStatus.failure,
          errorMessage: () => e.toString(),
        ),
      );
    }
  }
}

