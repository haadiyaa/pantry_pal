import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/receipt/domain/services/expiry_suggester.dart';

void main() {
  const suggester = ExpirySuggester();

  group('ExpirySuggester - guessCategory', () {
    test('guesses Dairy for milk, yogurt, paneer, butter, cheese', () {
      expect(suggester.guessCategory('Amul Taaza Milk 500ml'), 'Dairy');
      expect(suggester.guessCategory('Greek Yogurt Plain'), 'Dairy');
      expect(suggester.guessCategory('Fresh Malai Paneer 200g'), 'Dairy');
      expect(suggester.guessCategory('Salted Butter 100g'), 'Dairy');
      expect(suggester.guessCategory('Cheddar Cheese Slices'), 'Dairy');
    });

    test('guesses Vegetables for onion, tomato, spinach, potato', () {
      expect(suggester.guessCategory('Red Onions 1kg'), 'Vegetables');
      expect(suggester.guessCategory('Hybrid Tomato'), 'Vegetables');
      expect(suggester.guessCategory('Baby Spinach Palak'), 'Vegetables');
      expect(suggester.guessCategory('Fresh Potato 2kg'), 'Vegetables');
    });

    test('guesses Fruits for apple, banana, mango, orange', () {
      expect(suggester.guessCategory('Shimla Apple 1kg'), 'Fruits');
      expect(suggester.guessCategory('Robusta Banana 6pcs'), 'Fruits');
      expect(suggester.guessCategory('Alphonso Mango'), 'Fruits');
    });

    test('guesses Meat and Fish for chicken, fish, eggs, mutton', () {
      expect(suggester.guessCategory('Fresh Chicken Breast 500g'), 'Meat and Fish');
      expect(suggester.guessCategory('Farm Fresh Eggs 6 Pack'), 'Meat and Fish');
      expect(suggester.guessCategory('Rohu Fish Curry Cut'), 'Meat and Fish');
    });

    test('guesses Grains for rice, atta, bread, dal, oats, pasta', () {
      expect(suggester.guessCategory('India Gate Basmati Rice 5kg'), 'Grains');
      expect(suggester.guessCategory('Aashirvaad Shudh Chakki Atta 10kg'), 'Grains');
      expect(suggester.guessCategory('Brown Bread 400g'), 'Grains');
      expect(suggester.guessCategory('Toor Dal 1kg'), 'Grains');
      expect(suggester.guessCategory('Rolled Oats 1kg'), 'Grains');
    });

    test('guesses Snacks for biscuits, chips, cookies, chocolate', () {
      expect(suggester.guessCategory('Parle-G Glucose Biscuits'), 'Snacks');
      expect(suggester.guessCategory('Lays Potato Chips'), 'Snacks');
      expect(suggester.guessCategory('Cadbury Dairy Milk Chocolate'), 'Snacks');
    });

    test('guesses Beverages for tea, coffee, juice, coke', () {
      expect(suggester.guessCategory('Tata Tea Gold 500g'), 'Beverages');
      expect(suggester.guessCategory('Nescafe Classic Coffee 100g'), 'Beverages');
      expect(suggester.guessCategory('Real Orange Juice 1L'), 'Beverages');
      expect(suggester.guessCategory('Coca Cola 750ml'), 'Beverages');
    });

    test('guesses Frozen for ice cream, frozen peas', () {
      expect(suggester.guessCategory('Vadilal Vanilla Ice Cream 1L'), 'Frozen');
      expect(suggester.guessCategory('Safal Frozen Green Peas 500g'), 'Frozen');
    });

    test('defaults to Other for unrecognized items', () {
      expect(suggester.guessCategory('Dishwashing Liquid 500ml'), 'Other');
      expect(suggester.guessCategory('Laundry Detergent'), 'Other');
      expect(suggester.guessCategory('Stainless Steel Scrubber'), 'Other');
    });
  });

  group('ExpirySuggester - suggestExpiryDate', () {
    final fixedDate = DateTime(2026, 10, 28);

    test('calculates correct shelf-life for each category from baseDate', () {
      // Dairy: +7 days
      expect(
        suggester.suggestExpiryDate(category: 'Dairy', baseDate: fixedDate),
        DateTime(2026, 11, 4),
      );

      // Vegetables: +5 days
      expect(
        suggester.suggestExpiryDate(category: 'Vegetables', baseDate: fixedDate),
        DateTime(2026, 11, 2),
      );

      // Fruits: +5 days
      expect(
        suggester.suggestExpiryDate(category: 'Fruits', baseDate: fixedDate),
        DateTime(2026, 11, 2),
      );

      // Meat and Fish: +2 days
      expect(
        suggester.suggestExpiryDate(category: 'Meat and Fish', baseDate: fixedDate),
        DateTime(2026, 10, 30),
      );

      // Grains: +180 days
      expect(
        suggester.suggestExpiryDate(category: 'Grains', baseDate: fixedDate),
        DateTime(2026, 10, 28 + 180),
      );

      // Snacks: +90 days
      expect(
        suggester.suggestExpiryDate(category: 'Snacks', baseDate: fixedDate),
        DateTime(2026, 10, 28 + 90),
      );

      // Beverages: +90 days
      expect(
        suggester.suggestExpiryDate(category: 'Beverages', baseDate: fixedDate),
        DateTime(2026, 10, 28 + 90),
      );

      // Frozen: +90 days
      expect(
        suggester.suggestExpiryDate(category: 'Frozen', baseDate: fixedDate),
        DateTime(2026, 10, 28 + 90),
      );

      // Other: +30 days
      expect(
        suggester.suggestExpiryDate(category: 'Other', baseDate: fixedDate),
        DateTime(2026, 10, 28 + 30),
      );
    });

    test('defaults to now when baseDate is null', () {
      final now = DateTime(2026, 5, 10);
      final suggested = suggester.suggestExpiryDate(
        category: 'Dairy',
        now: now,
      );
      expect(suggested, DateTime(2026, 5, 17));
    });
  });
}

