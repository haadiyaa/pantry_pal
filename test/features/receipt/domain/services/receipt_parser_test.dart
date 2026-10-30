import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/receipt/domain/models/draft_item.dart';
import 'package:pantry_pal/features/receipt/domain/services/receipt_parser.dart';

import '../../../../fixtures/receipts/fixture_helper.dart';

void main() {
  late ReceiptParser parser;

  setUp(() {
    parser = const ReceiptParser();
  });

  group('ReceiptParser Fixture Tests', () {
    test('1. Supermarket multi-column format with qty, rate, amount', () {
      final lines = ReceiptFixtureHelper.loadFixture('supermarket_multicolumn');
      final draft = parser.parse(lines);

      expect(draft.receiptDate, DateTime(2026, 10, 28));
      expect(draft.items.length, 2);

      // Item 1: Amul Taaza Milk 500ml
      final item1 = draft.items[0];
      expect(item1.name, 'Amul Taaza Milk 500ml');
      expect(item1.quantity, 2);
      expect(item1.priceInPaise, 6400); // Rs. 64.00
      expect(item1.category, 'Dairy');
      expect(item1.confidence, ItemConfidence.high);

      // Item 2: Modern White Bread 400g
      final item2 = draft.items[1];
      expect(item2.name, 'Modern White Bread 400g');
      expect(item2.quantity, 1);
      expect(item2.priceInPaise, 4500); // Rs. 45.00
      expect(item2.category, 'Grains');

      // Assert header and totals were excluded
      final names = draft.items.map((i) => i.name.toLowerCase()).toList();
      expect(names.any((n) => n.contains('spencer')), isFalse);
      expect(names.any((n) => n.contains('subtotal')), isFalse);
      expect(names.any((n) => n.contains('grand total')), isFalse);
    });

    test('2. Simple name and amount receipt', () {
      final lines = ReceiptFixtureHelper.loadFixture('simple_name_amount');
      final draft = parser.parse(lines);

      expect(draft.receiptDate, DateTime(2026, 10, 15));
      expect(draft.items.length, 3);

      expect(draft.items[0].name, 'Tata Salt 1kg');
      expect(draft.items[0].priceInPaise, 2800);

      expect(draft.items[1].name, 'Aashirvaad Atta 5kg');
      expect(draft.items[1].priceInPaise, 26500);
      expect(draft.items[1].category, 'Grains');

      expect(draft.items[2].name, 'Fortune Sunflower Oil 1L');
      expect(draft.items[2].priceInPaise, 14500);

      // Exclude Kirana store header, cash paid, change due
      final names = draft.items.map((i) => i.name.toLowerCase()).toList();
      expect(names.any((n) => n.contains('kirana')), isFalse);
      expect(names.any((n) => n.contains('cash paid')), isFalse);
      expect(names.any((n) => n.contains('change due')), isFalse);
    });

    test('3. Receipt with GST, HSN, and Tax Invoice lines', () {
      final lines = ReceiptFixtureHelper.loadFixture('receipt_with_gst');
      final draft = parser.parse(lines);

      expect(draft.receiptDate, DateTime(2026, 9, 20));
      expect(draft.items.length, 2);

      // HSN 0401 prefix trimmed, clean title case
      expect(draft.items[0].name, 'Fresh Paneer 200g');
      expect(draft.items[0].priceInPaise, 8500);
      expect(draft.items[0].category, 'Dairy');

      // Leading code 0403 trimmed
      expect(draft.items[1].name, 'Greek Yogurt Blueberry');
      expect(draft.items[1].priceInPaise, 6000);
      expect(draft.items[1].category, 'Dairy');

      // GST and metadata excluded
      final names = draft.items.map((i) => i.name.toLowerCase()).toList();
      expect(names.any((n) => n.contains('gstin')), isFalse);
      expect(names.any((n) => n.contains('cgst')), isFalse);
      expect(names.any((n) => n.contains('sgst')), isFalse);
      expect(names.any((n) => n.contains('net payable')), isFalse);
      expect(names.any((n) => n.contains('upi')), isFalse);
    });

    test('4. Receipt with discounts, savings, and round-off', () {
      final lines = ReceiptFixtureHelper.loadFixture('receipt_with_discounts');
      final draft = parser.parse(lines);

      expect(draft.receiptDate, DateTime(2026, 10, 12));
      expect(draft.items.length, 2);

      expect(draft.items[0].name, 'Kelloggs Corn Flakes 500g');
      expect(draft.items[0].priceInPaise, 19500);
      expect(draft.items[0].category, 'Grains');

      expect(draft.items[1].name, 'Good Day Butter Cookies 200g');
      expect(draft.items[1].priceInPaise, 4550);
      expect(draft.items[1].category, 'Snacks');

      // Exclude discounts, savings, round off
      final names = draft.items.map((i) => i.name.toLowerCase()).toList();
      expect(names.any((n) => n.contains('discount')), isFalse);
      expect(names.any((n) => n.contains('saved')), isFalse);
      expect(names.any((n) => n.contains('round off')), isFalse);
      expect(names.any((n) => n.contains('total item')), isFalse);
    });

    test('5. Receipt with OCR noise in numeric positions (O for 0, l for 1)', () {
      final lines = ReceiptFixtureHelper.loadFixture('ocr_noise_digits');
      final draft = parser.parse(lines);

      expect(draft.receiptDate, DateTime(2026, 10, 5));
      expect(draft.items.length, 2);

      // 'l' repaired to qty 1, '5O.OO' repaired to 5000 paise
      expect(draft.items[0].name, 'Amul Butter 100g');
      expect(draft.items[0].quantity, 1);
      expect(draft.items[0].priceInPaise, 5000);
      expect(draft.items[0].category, 'Dairy');

      // '14O,OO' repaired to 14000 paise
      expect(draft.items[1].name, 'Britannia Cheese Slices');
      expect(draft.items[1].priceInPaise, 14000);
      expect(draft.items[1].category, 'Dairy');
    });

    test('6. Empty or garbage input returns empty draft without crashing', () {
      final lines = ReceiptFixtureHelper.loadFixture('empty_garbage');
      final draft = parser.parse(lines);

      expect(draft.items, isEmpty);
      expect(draft.receiptDate, isNull);

      // Empty list
      final emptyDraft = parser.parse([]);
      expect(emptyDraft.items, isEmpty);
    });
  });

  group('Money Parsing Edge Cases (ReceiptParser.parseMoneyToPaise)', () {
    test('parses various standard and noisy currency strings into integer paise', () {
      expect(ReceiptParser.parseMoneyToPaise('45'), 4500);
      expect(ReceiptParser.parseMoneyToPaise('45.5'), 4550);
      expect(ReceiptParser.parseMoneyToPaise('45.50'), 4550);
      expect(ReceiptParser.parseMoneyToPaise('1,299.00'), 129900);
      expect(ReceiptParser.parseMoneyToPaise('Rs. 45/-'), 4500);
      expect(ReceiptParser.parseMoneyToPaise('₹ 1,299.00'), 129900);
      expect(ReceiptParser.parseMoneyToPaise('MRP 250'), 25000);
      expect(ReceiptParser.parseMoneyToPaise('45,50'), 4550); // comma decimal
      expect(ReceiptParser.parseMoneyToPaise('5O.OO'), 5000); // OCR O for 0
      expect(ReceiptParser.parseMoneyToPaise('l45.OO'), 14500); // OCR l for 1
      expect(ReceiptParser.parseMoneyToPaise('S5.OO'), 5500); // OCR S for 5
      expect(ReceiptParser.parseMoneyToPaise('invalid text'), isNull);
      expect(ReceiptParser.parseMoneyToPaise(''), isNull);
    });
  });

  group('Title Case Formatting', () {
    test('converts strings to title case while preserving units', () {
      expect(
        ReceiptParser.toTitleCase('AMUL TAAZA MILK 500ML'),
        'Amul Taaza Milk 500ml',
      );
      expect(
        ReceiptParser.toTitleCase('tata salt 1kg'),
        'Tata Salt 1kg',
      );
      expect(
        ReceiptParser.toTitleCase('FORTUNE SUNFLOWER OIL 1L'),
        'Fortune Sunflower Oil 1L',
      );
    });
  });
}
