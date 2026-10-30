import '../constants/receipt_parser_constants.dart';

/// Pure functional service for calculating estimated expiry dates based on item category
/// and the purchase/receipt date.
/// Has zero Flutter framework dependencies.
class ExpirySuggester {
  const ExpirySuggester();

  /// Calculates an estimated expiry date based on [category] and [baseDate].
  /// If [baseDate] is omitted or null, defaults to the current evaluation day [now].
  DateTime suggestExpiryDate({
    required String category,
    DateTime? baseDate,
    DateTime? now,
  }) {
    final start = baseDate ?? now ?? DateTime.now();
    final days = ReceiptParserConstants.defaultShelfLifeDays[category] ??
        ReceiptParserConstants.defaultShelfLifeDays['Other']!;

    return DateTime(
      start.year,
      start.month,
      start.day + days,
    );
  }

  /// Maps an item name to one of the standard pantry categories using keyword matching.
  /// Defaults to 'Other' if no confident match is found.
  String guessCategory(String itemName) {
    final lowerName = itemName.toLowerCase().trim();
    if (lowerName.isEmpty) return 'Other';

    // Prioritized direct checks for specific product forms to avoid ingredient shadowing:
    // e.g. "ice cream" is Frozen (not Dairy), "potato chips" is Snacks (not Vegetables),
    // "orange juice" is Beverages (not Fruits), "butter cookies" is Snacks (not Dairy).
    for (final entry in ReceiptParserConstants.categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        final pattern =
            RegExp(r'\b' + RegExp.escape(keyword) + r'(s|es)?\b');
        if (pattern.hasMatch(lowerName)) {
          return category;
        }
      }
    }

    return 'Other';
  }
}
