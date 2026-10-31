import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/stats/domain/models/category_stat.dart';
import 'package:pantry_pal/features/stats/domain/models/item_stat.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_period.dart';
import 'package:pantry_pal/features/stats/domain/models/stats_summary.dart';
import 'package:pantry_pal/features/stats/domain/models/time_bucket.dart';
import 'package:pantry_pal/features/stats/presentation/cubit/stats_cubit.dart';
import 'package:pantry_pal/features/stats/presentation/cubit/stats_state.dart';
import 'package:pantry_pal/features/stats/presentation/pages/stats_page.dart';
import 'package:pantry_pal/features/stats/presentation/widgets/insight_card.dart';
import 'package:pantry_pal/features/stats/presentation/widgets/summary_cards_grid.dart';

class MockStatsCubit extends MockCubit<StatsState> implements StatsCubit {}

void main() {
  late MockStatsCubit mockStatsCubit;

  final sampleSummary = StatsSummary(
    period: StatsPeriod.last30Days,
    totalEvents: 10,
    rescuedUnits: 6,
    usedLateUnits: 2,
    wastedUnits: 2,
    wasteRate: 0.20,
    valueUsedPaise: 45000, // ₹450
    usedPricedUnits: 8,
    valueWastedPaise: 12000, // ₹120
    wastedPricedUnits: 2,
    daysSinceLastWaste: 4,
    timeBuckets: [
      TimeBucket(
        start: DateTime(2026, 5, 1),
        end: DateTime(2026, 5, 7),
        label: '1 May',
        usedCount: 4,
        wastedCount: 1,
      ),
      TimeBucket(
        start: DateTime(2026, 5, 8),
        end: DateTime(2026, 5, 14),
        label: '8 May',
        usedCount: 4,
        wastedCount: 1,
      ),
    ],
    categoryBreakdown: const [
      CategoryStat(
        category: 'Dairy',
        wastedUnits: 2,
        totalPricePaise: 12000,
        percentage: 100.0,
      ),
    ],
    topWastedItems: const [
      ItemStat(
        name: 'Amul Milk',
        units: 2,
        totalPricePaise: 12000,
        pricedUnits: 2,
      ),
    ],
    topUsedItems: const [
      ItemStat(
        name: 'Whole Wheat Bread',
        units: 4,
        totalPricePaise: 20000,
        pricedUnits: 4,
      ),
    ],
    insight: 'You rescue most of your food before it expires — keep it up!',
  );

  setUpAll(() {
    registerFallbackValue(StatsPeriod.last30Days);
  });

  setUp(() {
    mockStatsCubit = MockStatsCubit();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<StatsCubit>.value(
        value: mockStatsCubit,
        child: const StatsPage(),
      ),
    );
  }

  group('StatsPage', () {
    testWidgets('renders loading spinner when loading and summary is null', (tester) async {
      when(() => mockStatsCubit.state).thenReturn(
        const StatsState(status: StatsStatus.loading, summary: null),
      );

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error view with retry button on failure', (tester) async {
      when(() => mockStatsCubit.state).thenReturn(
        const StatsState(
          status: StatsStatus.failure,
          errorMessage: 'Unable to connect to database',
        ),
      );
      when(() => mockStatsCubit.refresh()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Failed to load statistics'), findsOneWidget);
      expect(find.text('Unable to connect to database'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      verify(() => mockStatsCubit.refresh()).called(1);
    });

    testWidgets('renders summary cards, insight banner, charts and top items', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockStatsCubit.state).thenReturn(
        StatsState(
          status: StatsStatus.success,
          period: StatsPeriod.last30Days,
          summary: sampleSummary,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Insight banner
      expect(find.byType(InsightCard), findsOneWidget);
      expect(find.textContaining('You rescue most of your food'), findsOneWidget);

      // Summary grid cards
      expect(find.byType(SummaryCardsGrid), findsOneWidget);
      expect(find.text('Rescued Items'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Wasted Items'), findsOneWidget);
      expect(find.text('Waste Rate'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
      expect(find.text('Clean Streak'), findsOneWidget);
      expect(find.text('4 days'), findsOneWidget);

      // Value formatting
      expect(find.text('Value Used'), findsOneWidget);
      expect(find.text('Value Wasted'), findsOneWidget);

      // Top items
      expect(find.text('Amul Milk'), findsOneWidget);
      expect(find.text('Whole Wheat Bread'), findsOneWidget);
    });

    testWidgets('tapping period segments calls cubit.changePeriod', (tester) async {
      when(() => mockStatsCubit.state).thenReturn(
        StatsState(
          status: StatsStatus.success,
          period: StatsPeriod.last30Days,
          summary: sampleSummary,
        ),
      );
      when(() => mockStatsCubit.changePeriod(any())).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap 7d segment
      await tester.tap(find.text('7d'));
      verify(() => mockStatsCubit.changePeriod(StatsPeriod.last7Days)).called(1);

      // Tap 90d segment
      await tester.tap(find.text('90d'));
      verify(() => mockStatsCubit.changePeriod(StatsPeriod.last90Days)).called(1);
    });

    testWidgets('long pressing title opens developer bottom sheet', (tester) async {
      when(() => mockStatsCubit.state).thenReturn(
        StatsState(
          status: StatsStatus.success,
          period: StatsPeriod.last30Days,
          summary: sampleSummary,
        ),
      );
      when(() => mockStatsCubit.insertSampleData()).thenAnswer((_) async {});
      when(() => mockStatsCubit.clearSampleData()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Long press page title
      await tester.longPress(find.text('Waste Statistics'));
      await tester.pumpAndSettle();

      expect(find.text('Developer Actions'), findsOneWidget);
      expect(find.text('Insert 4 months of sample data'), findsOneWidget);
      expect(find.text('Clear sample data'), findsOneWidget);

      // Tap insert
      await tester.tap(find.text('Insert 4 months of sample data'));
      await tester.pumpAndSettle();
      verify(() => mockStatsCubit.insertSampleData()).called(1);
    });

    testWidgets('renders empty state gracefully when there is no activity', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptySummary = StatsSummary(
        period: StatsPeriod.last7Days,
        totalEvents: 0,
        rescuedUnits: 0,
        usedLateUnits: 0,
        wastedUnits: 0,
        wasteRate: null,
        valueUsedPaise: 0,
        usedPricedUnits: 0,
        valueWastedPaise: 0,
        wastedPricedUnits: 0,
        daysSinceLastWaste: null,
        timeBuckets: const [],
        categoryBreakdown: const [],
        topWastedItems: const [],
        topUsedItems: const [],
      );

      when(() => mockStatsCubit.state).thenReturn(
        StatsState(
          status: StatsStatus.success,
          period: StatsPeriod.last7Days,
          summary: emptySummary,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Waste rate should show "No data yet"
      expect(find.text('No data yet'), findsOneWidget);
      expect(find.text('No waste recorded yet'), findsOneWidget);
      expect(find.text('No wasted food recorded in this period! 🎉'), findsOneWidget);
      expect(find.text('No wasted items to display.'), findsOneWidget);
      expect(find.text('No consumed items recorded yet.'), findsOneWidget);
    });
  });
}
