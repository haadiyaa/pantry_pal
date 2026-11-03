import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/app_snackbar.dart';
import '../../domain/models/stats_period.dart';
import '../cubit/stats_cubit.dart';
import '../cubit/stats_state.dart';
import '../widgets/category_waste_donut_chart.dart';
import '../widgets/insight_card.dart';
import '../widgets/summary_cards_grid.dart';
import '../widgets/top_items_section.dart';
import '../widgets/used_vs_wasted_bar_chart.dart';

/// Screen presenting food waste analytics, time-series charts, and top items.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  void _showDeveloperMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.developer_mode, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Developer Actions',
                      style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Insert mock events across 4 months for testing and screenshots, or clear them.',
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.post_add_outlined, color: Colors.green),
                  title: const Text('Insert 4 months of sample data'),
                  subtitle: const Text('Seeds ~60 realistic used & wasted pantry events'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.read<StatsCubit>().insertSampleData();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  title: const Text('Clear sample data'),
                  subtitle: const Text('Deletes all test sample records'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.read<StatsCubit>().clearSampleData();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          key: const Key('stats_appbar_title'),
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _showDeveloperMenu(context),
          child: const Text('Waste Statistics'),
        ),
      ),
      body: BlocConsumer<StatsCubit, StatsState>(
        listenWhen: (previous, current) =>
            current.actionMessage != null && current.actionMessage != previous.actionMessage,
        listener: (context, state) {
          final message = state.actionMessage;
          if (message != null) {
            AppSnackBar.showInfo(
              context,
              message: message,
            );
            context.read<StatsCubit>().clearActionMessage();
          }
        },
        builder: (context, state) {
          if (state.status == StatsStatus.loading && state.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == StatsStatus.failure && state.summary == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load statistics',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.errorMessage ?? 'An unexpected error occurred.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.read<StatsCubit>().refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final summary = state.summary;
          if (summary == null) {
            return const SizedBox.shrink();
          }

          return RefreshIndicator(
            onRefresh: () => context.read<StatsCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _PeriodSelector(
                  selectedPeriod: state.period,
                  onSelected: (period) => context.read<StatsCubit>().changePeriod(period),
                ),
                const SizedBox(height: 16),
                if (summary.insight != null) ...[
                  InsightCard(insightText: summary.insight!),
                  const SizedBox(height: 16),
                ],
                SummaryCardsGrid(summary: summary),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: UsedVsWastedBarChart(
                      buckets: summary.timeBuckets,
                      period: state.period,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CategoryWasteDonutChart(
                      categories: summary.categoryBreakdown,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TopItemsSection(
                  topWastedItems: summary.topWastedItems,
                  topUsedItems: summary.topUsedItems,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onSelected,
  });

  final StatsPeriod selectedPeriod;
  final ValueChanged<StatsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<StatsPeriod>(
        segments: const [
          ButtonSegment(
            value: StatsPeriod.last7Days,
            label: Text('7d'),
            tooltip: 'Last 7 Days',
          ),
          ButtonSegment(
            value: StatsPeriod.last30Days,
            label: Text('30d'),
            tooltip: 'Last 30 Days',
          ),
          ButtonSegment(
            value: StatsPeriod.last90Days,
            label: Text('90d'),
            tooltip: 'Last 90 Days',
          ),
          ButtonSegment(
            value: StatsPeriod.allTime,
            label: Text('All'),
            tooltip: 'All Time',
          ),
        ],
        selected: {selectedPeriod},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onSelected(selection.first);
          }
        },
      ),
    );
  }
}
