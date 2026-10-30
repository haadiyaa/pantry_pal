import '../constants/receipt_parser_constants.dart';
import '../models/draft_item.dart';
import '../models/receipt_draft.dart';
import '../models/recognized_line.dart';
import 'expiry_suggester.dart';

/// Pure Dart service that converts raw OCR recognized lines and coordinates
/// into structured, high-accuracy [ReceiptDraft] instances.
/// Zero Flutter framework, UI, or plugin dependencies.
class ReceiptParser {
  const ReceiptParser({
    this.expirySuggester = const ExpirySuggester(),
  });

  final ExpirySuggester expirySuggester;

  /// Parses [lines] with bounding boxes into a [ReceiptDraft].
  /// Guaranteed never to throw on garbage, empty, or malformed input.
  ReceiptDraft parse(List<RecognizedLine> lines, {DateTime? now}) {
    if (lines.isEmpty) {
      return const ReceiptDraft(items: []);
    }

    try {
      final evaluationNow = now ?? DateTime.now();

      // 1. Extract receipt date from raw lines
      final receiptDate = _extractReceiptDate(lines);

      // 2. Group lines into horizontal visual rows using bounding boxes
      final rows = _groupIntoVisualRows(lines);

      // 3. Parse items from candidate rows
      final draftItems = <DraftItem>[];

      for (final row in rows) {
        if (_isIgnoredRow(row)) continue;

        final item = _parseItemRow(row, receiptDate ?? evaluationNow);
        if (item != null) {
          draftItems.add(item);
        }
      }

      return ReceiptDraft(
        items: draftItems,
        receiptDate: receiptDate,
      );
    } catch (_) {
      // Robustness requirement: Never crash on malformed/garbage input
      return const ReceiptDraft(items: []);
    }
  }

  /// Groups bounding-box annotated lines into unified horizontal text rows.
  List<String> _groupIntoVisualRows(List<RecognizedLine> lines) {
    if (lines.isEmpty) return const [];

    final validLines = lines
        .where((l) => l.text.trim().isNotEmpty)
        .toList();

    if (validLines.isEmpty) return const [];

    // Sort top-to-bottom
    validLines.sort((a, b) => a.verticalPosition.compareTo(b.verticalPosition));

    final clusters = <List<RecognizedLine>>[];

    for (final line in validLines) {
      bool matched = false;
      for (final cluster in clusters) {
        final reference = cluster.first;
        if (line.boundingBox.isOnSameRow(reference.boundingBox)) {
          cluster.add(line);
          matched = true;
          break;
        }
      }
      if (!matched) {
        clusters.add([line]);
      }
    }

    // Sort lines horizontally within each cluster (left to right) and join
    final rows = <String>[];
    for (final cluster in clusters) {
      cluster.sort((a, b) => a.horizontalPosition.compareTo(b.horizontalPosition));
      final joined = cluster.map((l) => l.text.trim()).join(' ');
      if (joined.trim().isNotEmpty) {
        rows.add(joined.trim());
      }
    }

    return rows;
  }

  /// Checks if a row represents metadata, headers, tax, totals, or greetings.
  bool _isIgnoredRow(String row) {
    final lower = row.toLowerCase().trim();
    if (lower.isEmpty) return true;

    // Check against centralized ignore keywords
    for (final keyword in ReceiptParserConstants.ignoredLineKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }

    // Ignore lines with date, time, invoice prefixes
    if (RegExp(r'\b(date|time|invoice|bill)\s*[:\-]', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // Ignore lines that are purely dates or times
    if (RegExp(r'^[\d\s/:.-]+(am|pm)?$', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // Ignore lines consisting purely of divider symbols or punctuation
    if (RegExp(r'^[\s\-_=*#.,~:;/\\]+$').hasMatch(lower)) {
      return true;
    }

    // Ignore single character or very short non-alphabetic lines
    if (lower.length <= 1) return true;

    return false;
  }

  /// Extracts transaction date if present on the receipt.
  DateTime? _extractReceiptDate(List<RecognizedLine> lines) {
    final text = lines.map((l) => l.text).join(' ');

    // 1. dd/mm/yyyy or dd-mm-yyyy or dd.mm.yyyy or dd/mm/yy
    final numericDateRegex = RegExp(
      r'\b(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})\b',
    );
    for (final match in numericDateRegex.allMatches(text)) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      var year = int.tryParse(match.group(3)!);

      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 2000 && year <= 2099) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }
    }

    // 2. dd Mon yyyy (e.g. 28 Oct 2026, 28-OCT-2026)
    final wordMonthRegex = RegExp(
      r'\b(\d{1,2})[\s\.-](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*[\s\.-](\d{2,4})\b',
      caseSensitive: false,
    );
    final monthMap = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    final wordMatch = wordMonthRegex.firstMatch(text);
    if (wordMatch != null) {
      final day = int.tryParse(wordMatch.group(1)!);
      final monthStr = wordMatch.group(2)!.toLowerCase();
      var year = int.tryParse(wordMatch.group(3)!);
      final month = monthMap[monthStr];

      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        if (day >= 1 && day <= 31 && year >= 2000 && year <= 2099) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }
    }

    return null;
  }

  /// Parses a single candidate visual row into a [DraftItem].
  DraftItem? _parseItemRow(String rawRow, DateTime baseDate) {
    var row = rawRow.trim();

    // Check for HSN / SAC prefix and trim: e.g. "0401 MILK" or "HSN: 0401 MILK"
    row = row.replaceFirst(RegExp(r'^HSN\s*[:\-]?\s*\d+\s*', caseSensitive: false), '');
    row = row.replaceFirst(RegExp(r'^\d{4,8}\s+'), ''); // Strip leading barcode/item ID

    final tokens = row.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;

    int? parsedQuantity = 1;
    int? parsedPricePaise;
    int? unitRatePaise;
    ItemConfidence confidence = ItemConfidence.high;

    // 1. Check for "qty x rate" pattern: e.g. "2 x 45.00" or "2 X 45.00"
    final qtyXRateRegex = RegExp(
      r'(\d+)\s*[xX]\s*([₹Rs\.]*[\d,OolISs]+(?:\.[\d,OolISs]+)?)',
    );
    final qtyXMatch = qtyXRateRegex.firstMatch(row);
    if (qtyXMatch != null) {
      parsedQuantity = int.tryParse(qtyXMatch.group(1)!);
      final rateStr = qtyXMatch.group(2)!;
      final ratePaise = parseMoneyToPaise(rateStr);
      if (ratePaise != null) {
        parsedPricePaise = ratePaise * (parsedQuantity ?? 1);
      }
      row = row.replaceFirst(qtyXMatch.group(0)!, '').trim();
    }

    // 2. Token extraction from right to left:
    // Look for Amount (total price), then Rate (unit price), then Quantity
    final remainingTokens = row.split(RegExp(r'\s+'));
    final nameTokens = <String>[];

    for (var i = remainingTokens.length - 1; i >= 0; i--) {
      final token = remainingTokens[i];
      final isPotentialPrice = _isPotentialPriceToken(token);

      if (isPotentialPrice) {
        final paise = parseMoneyToPaise(token);
        if (paise != null) {
          if (parsedPricePaise == null) {
            parsedPricePaise = paise;
            continue;
          } else if (unitRatePaise == null) {
            unitRatePaise = paise;
            continue;
          }
        }
      }

      // Check for quantity token: e.g. "2" or OCR "l"
      if (parsedPricePaise != null && parsedQuantity == 1 && _isPureQuantityToken(token)) {
        final q = int.tryParse(_repairOcrDigits(token));
        if (q != null && q > 0 && q <= 99) {
          parsedQuantity = q;
          continue;
        }
      }

      nameTokens.insert(0, token);
    }

    // In retail grocery receipts, every actual purchased item has a price
    if (parsedPricePaise == null) {
      return null;
    }

    // If unit rate is present and no explicit quantity was specified, check if price/rate implies quantity
    if (unitRatePaise != null && unitRatePaise > 0 && parsedQuantity == 1) {
      if (parsedPricePaise % unitRatePaise == 0 && parsedPricePaise > unitRatePaise) {
        parsedQuantity = parsedPricePaise ~/ unitRatePaise;
      }
    }

    var cleanedName = nameTokens.join(' ').trim();

    // Clean remaining trailing prices, rates, currency prefixes, or punctuation from name
    cleanedName = cleanedName
        .replaceFirst(RegExp(r'[\s\-:–]+$'), '')
        .replaceFirst(RegExp(r'^[0-9\.\-\s]+'), '') // leading numbers or dots
        .replaceFirst(RegExp(r'\s+(Rs\.?|₹|INR|MRP)$', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s+[\d,OolISs]+(?:\.[\d,OolISs]+)?$'), '') // trailing rate decimals
        .trim();

    // Must have at least 2 alphabetic characters to be a valid grocery item
    final letterCount = cleanedName.replaceAll(RegExp(r'[^a-zA-Z]'), '').length;
    if (letterCount < 2) {
      return null;
    }

    if (letterCount <= 3 || cleanedName.contains(RegExp(r'[^a-zA-Z0-9\s\.\-&/()]'))) {
      confidence = ItemConfidence.low;
    }

    final formattedName = toTitleCase(cleanedName);
    final category = expirySuggester.guessCategory(formattedName);
    final suggestedExpiry = expirySuggester.suggestExpiryDate(
      category: category,
      baseDate: baseDate,
    );

    return DraftItem(
      name: formattedName,
      quantity: parsedQuantity ?? 1,
      priceInPaise: parsedPricePaise,
      category: category,
      confidence: confidence,
      isIncluded: true,
      suggestedExpiryDate: suggestedExpiry,
    );
  }

  /// Whether a token looks like a currency/price token.
  bool _isPotentialPriceToken(String token) {
    final clean = token
        .replaceAll(RegExp(r'^[₹RsMRP\.\s/]+', caseSensitive: false), '')
        .replaceAll(RegExp(r'[/\-=]+$'), '');

    if (clean.isEmpty) return false;

    // Has currency symbol or suffix in original token
    final hasCurrencyIndicator = RegExp(
      r'^(Rs\.?|₹|INR|MRP)|[/\-=]$',
      caseSensitive: false,
    ).hasMatch(token);

    // If it has a decimal point or comma separator with decimals: "45.00", "5O.OO"
    if (clean.contains('.') || clean.contains(',')) {
      return RegExp(r'^[\dOolISsB]+[.,][\dOolISsB]+$').hasMatch(clean);
    }

    // If it has currency indicators: "Rs 45", "45/-"
    if (hasCurrencyIndicator) {
      return RegExp(r'^[\dOolISsB]+$').hasMatch(clean);
    }

    // Standalone single digits/characters are quantities, not prices
    if (clean.length == 1) {
      return false;
    }

    return RegExp(r'^\d{2,}$').hasMatch(clean);
  }

  bool _isPureQuantityToken(String token) {
    final clean = token.replaceAll(RegExp(r'[xX]$'), '');
    final repaired = _repairOcrDigits(clean);
    final num = int.tryParse(repaired);
    return num != null && num > 0 && num <= 99;
  }

  /// Public utility to parse money representations to integer paise.
  static int? parseMoneyToPaise(String raw) {
    if (raw.trim().isEmpty) return null;

    var text = raw.trim();

    // Strip currency symbols, prefixes, and suffixes
    text = text.replaceAll(RegExp(r'^(Rs\.?|₹|INR|MRP)\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'[/\-=]+$'), '');
    text = text.trim();

    // Repair OCR digits inside the numeric token
    text = _repairOcrDigits(text);

    // Normalize comma as decimal if single comma with 1-2 digits: e.g. "45,50" -> "45.50"
    if (RegExp(r'^\d+,\d{1,2}$').hasMatch(text)) {
      text = text.replaceAll(',', '.');
    } else {
      // Remove thousands separators: "1,299.00" -> "1299.00"
      text = text.replaceAll(',', '');
    }

    if (text.isEmpty) return null;

    // Decimal format: e.g. "1299.00" or "45.5"
    if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length != 2) return null;

      final rupees = int.tryParse(parts[0]);
      if (rupees == null) return null;

      var paiseStr = parts[1];
      if (paiseStr.length == 1) {
        paiseStr += '0'; // 45.5 -> 50 paise
      } else if (paiseStr.length > 2) {
        paiseStr = paiseStr.substring(0, 2); // Truncate fractional paise
      }

      final paise = int.tryParse(paiseStr);
      if (paise == null) return null;

      return (rupees * 100) + paise;
    }

    // Pure integer: "45" -> 4500 paise
    final integerRupees = int.tryParse(text);
    if (integerRupees != null) {
      return integerRupees * 100;
    }

    return null;
  }

  /// Repairs common OCR substitution errors inside numeric tokens ONLY.
  static String _repairOcrDigits(String token) {
    return token
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('l', '1')
        .replaceAll('I', '1')
        .replaceAll('|', '1')
        .replaceAll('S', '5')
        .replaceAll('s', '5');
  }

  /// Converts arbitrary string to Title Case while preserving standard units (kg, g, ml, L).
  static String toTitleCase(String input) {
    if (input.trim().isEmpty) return '';

    final words = input.trim().split(RegExp(r'\s+'));
    final formatted = words.map((word) {
      if (word.isEmpty) return '';

      // Preserve units like 500ml, 1kg, 1L, 2pc
      final unitMatch = RegExp(
        r'^(\d+)(kg|g|ml|l|pc|pack|gm|ltr)$',
        caseSensitive: false,
      ).firstMatch(word);
      if (unitMatch != null) {
        final numPart = unitMatch.group(1)!;
        var unitPart = unitMatch.group(2)!.toLowerCase();
        if (unitPart == 'l') unitPart = 'L';
        return '$numPart$unitPart';
      }

      final lower = word.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');

    return formatted;
  }
}
