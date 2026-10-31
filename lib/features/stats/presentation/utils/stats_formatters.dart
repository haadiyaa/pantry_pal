import 'package:intl/intl.dart';

/// Formatter utilities for waste statistics display.
class StatsFormatters {
  const StatsFormatters._();

  /// Formats integer paise to INR currency string.
  /// Uses zero decimal digits for exact rupees (₹120) and two digits for fractional amounts (₹120.50).
  static String formatPaise(int paise) {
    final rupees = paise / 100.0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: paise % 100 == 0 ? 0 : 2,
    );
    return formatter.format(rupees);
  }

  /// Formats decimal rate (0.0 to 1.0) into percentage string (e.g., "15.5%").
  /// Returns "No data yet" if the rate is null.
  static String formatPercent(double? rate) {
    if (rate == null) return 'No data yet';
    return '${(rate * 100).toStringAsFixed(1)}%';
  }
}

