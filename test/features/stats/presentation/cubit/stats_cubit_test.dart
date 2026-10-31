import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_event.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_period.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_raw_data.dart';
import 'package:pantry_pal/features/stats/domain/repositories/stats_period_repository.dart';
import 'package:pantry_pal/features/stats/domain/repositories/stats_repository.dart';
import 'package:pantry_pal/features/stats/presentation/cubit/stats_cubit.dart';
import 'package:pantry_pal/features/stats/presentation/cubit/stats_state.dart';

class MockStatsRepository extends Mock implements StatsRepository {}

class MockStatsPeriodRepository extends Mock implements StatsPeriodRepository {}

void main() {
  late MockStatsRepository statsRepo;
  late MockStatsPeriodRepository periodRepo;
  final fixedNow = DateTime(2026, 5, 15, 14, 30);

  const emptyRawData = StatsRawData.empty;

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(StatsPeriod.last30Days);
    registerFallbackValue(<PantryEvent>[]);
  });

  setUp(() {
    statsRepo = MockStatsRepository();
    periodRepo = MockStatsPeriodRepository();

    when(() => periodRepo.getSelectedPeriod())
        .thenAnswer((_) async => StatsPeriod.last30Days);
    when(() => periodRepo.setSelectedPeriod(any()))
        .thenAnswer((_) async {});
    when(() => statsRepo.getStatsData(start: any(named: 'start'), end: any(named: 'end')))
        .thenAnswer((_) async => emptyRawData);
  });

  StatsCubit buildCubit() {
    return StatsCubit(
      statsRepository: statsRepo,
      periodRepository: periodRepo,
      nowProvider: () => fixedNow,
    );
  }

  group('StatsCubit', () {
    test('initial state has default period last30Days and initial status', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(StatsStatus.initial));
      expect(cubit.state.period, equals(StatsPeriod.last30Days));
      expect(cubit.state.summary, isNull);
    });

    test('init restores persisted period and loads summary successfully', () async {
      when(() => periodRepo.getSelectedPeriod())
          .thenAnswer((_) async => StatsPeriod.last7Days);

      final cubit = buildCubit();
      await cubit.init();

      expect(cubit.state.status, equals(StatsStatus.success));
      expect(cubit.state.period, equals(StatsPeriod.last7Days));
      expect(cubit.state.summary, isNotNull);
      verify(() => periodRepo.getSelectedPeriod()).called(1);
      verify(() => statsRepo.getStatsData(
            start: StatsPeriod.last7Days.getStartDate(fixedNow),
            end: StatsPeriod.last7Days.getEndDate(fixedNow),
          )).called(1);
    });

    test('changePeriod persists period and updates summary', () async {
      final cubit = buildCubit();
      await cubit.init();

      await cubit.changePeriod(StatsPeriod.allTime);

      expect(cubit.state.status, equals(StatsStatus.success));
      expect(cubit.state.period, equals(StatsPeriod.allTime));
      verify(() => periodRepo.setSelectedPeriod(StatsPeriod.allTime)).called(1);
    });

    test('rapid period switches cancel stale in-flight requests', () async {
      final completer7d = Completer<StatsRawData>();
      final completer90d = Completer<StatsRawData>();

      when(() => statsRepo.getStatsData(
            start: StatsPeriod.last7Days.getStartDate(fixedNow),
            end: StatsPeriod.last7Days.getEndDate(fixedNow),
          )).thenAnswer((_) => completer7d.future);

      when(() => statsRepo.getStatsData(
            start: StatsPeriod.last90Days.getStartDate(fixedNow),
            end: StatsPeriod.last90Days.getEndDate(fixedNow),
          )).thenAnswer((_) => completer90d.future);

      final cubit = buildCubit();

      // Trigger 7d then immediately 90d
      final f1 = cubit.changePeriod(StatsPeriod.last7Days);
      final f2 = cubit.changePeriod(StatsPeriod.last90Days);

      // Complete 7d first (stale)
      completer7d.complete(emptyRawData);
      // Complete 90d
      completer90d.complete(emptyRawData);

      await Future.wait([f1, f2]);

      // Cubit should only resolve to 90d
      expect(cubit.state.status, equals(StatsStatus.success));
      expect(cubit.state.period, equals(StatsPeriod.last90Days));
      expect(cubit.state.summary!.period, equals(StatsPeriod.last90Days));
    });

    test('emits failure state when repository throws exception', () async {
      when(() => statsRepo.getStatsData(start: any(named: 'start'), end: any(named: 'end')))
          .thenThrow(Exception('Database query failed'));

      final cubit = buildCubit();
      await cubit.init();

      expect(cubit.state.status, equals(StatsStatus.failure));
      expect(cubit.state.errorMessage, contains('Database query failed'));
      expect(cubit.state.summary, isNull);
    });

    test('insertSampleData generates events, inserts, and refreshes', () async {
      when(() => statsRepo.insertSampleEvents(any()))
          .thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.insertSampleData();

      expect(cubit.state.status, equals(StatsStatus.success));
      expect(cubit.state.actionMessage, isNotNull);
      verify(() => statsRepo.insertSampleEvents(any())).called(1);

      cubit.clearActionMessage();
      expect(cubit.state.actionMessage, isNull);
    });

    test('clearSampleData invokes clearSampleEvents and refreshes', () async {
      when(() => statsRepo.clearSampleEvents()).thenAnswer((_) async => 45);

      final cubit = buildCubit();
      await cubit.clearSampleData();

      expect(cubit.state.status, equals(StatsStatus.success));
      expect(cubit.state.actionMessage, contains('Cleared 45 sample records'));
      verify(() => statsRepo.clearSampleEvents()).called(1);
    });
  });
}
