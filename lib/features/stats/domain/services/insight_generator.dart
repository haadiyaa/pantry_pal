import '../models/category_stat.dart';
import '../models/stats_period.dart';

/// Pure functional service generating a single plain-language insight line from summary metrics.
///
/// Rules:
/// - Never shows an insight when there are fewer than 5 events in the period.
/// - Simple, deterministic, and free of platform dependencies.
class InsightGenerator {
  const InsightGenerator();

  String? generate({
    required StatsPeriod period,
    required int totalEvents,
    required int totalUsedUnits,
    required int rescuedUnits,
    required int wastedUnits,
    required double? wasteRate,
    required List<CategoryStat> categoryBreakdown,
  }) {
    // Insufficient data safeguard
    if (totalEvents < 5) return null;

    final periodPhrase = period == StatsPeriod.allTime
        ? 'of all time'
        : 'the ${period.label.toLowerCase()}';

    // Zero waste
    if (wastedUnits == 0) {
      return 'You wasted nothing in $periodPhrase!';
    }

    // Heavy single category concentration (>= 50% of wasted items)
    if (categoryBreakdown.isNotEmpty) {
      final topCat = categoryBreakdown.first;
      if (topCat.percentage >= 0.50) {
        final pctStr = (topCat.percentage * 100).toStringAsFixed(0);
        return '${topCat.category} is where most of your waste comes from in $periodPhrase ($pctStr% of wasted items).';
      }
    }

    // Low waste rate (< 10%)
    if (wasteRate != null && wasteRate < 0.10) {
      final rateStr = (wasteRate * 100).toStringAsFixed(1);
      return 'Great job keeping waste low! Your waste rate is $rateStr% in $periodPhrase.';
    }

    // Rescued praise with high waste warning (>= 35%)
    if (rescuedUnits > 0 && wasteRate != null && wasteRate >= 0.35) {
      final rateStr = (wasteRate * 100).toStringAsFixed(1);
      return 'You rescued $rescuedUnits items before expiry, but waste is currently at $rateStr% in $periodPhrase.';
    }

    // Default general insight
    return 'You consumed $totalUsedUnits items and threw away $wastedUnits in $periodPhrase.';
  }
}

