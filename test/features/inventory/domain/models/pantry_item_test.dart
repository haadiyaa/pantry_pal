import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';

void main() {
  group('PantryItem', () {
    final baseAddedAt = DateTime(2026, 1, 1);

    test('daysLeftAt returns 0 when expiry is the same day', () {
      final item = PantryItem(
        name: 'Milk',
        expiryDate: DateTime(2026, 5, 10, 15, 30),
        addedAt: baseAddedAt,
      );
      final today = DateTime(2026, 5, 10, 8, 0);

      expect(item.daysLeftAt(today), 0);
    });

    test('daysLeftAt returns positive whole days for future expiry', () {
      final item = PantryItem(
        name: 'Cheese',
        expiryDate: DateTime(2026, 5, 15),
        addedAt: baseAddedAt,
      );
      final today = DateTime(2026, 5, 10);

      expect(item.daysLeftAt(today), 5);
    });

    test('daysLeftAt returns negative whole days for past expiry', () {
      final item = PantryItem(
        name: 'Bread',
        expiryDate: DateTime(2026, 5, 8),
        addedAt: baseAddedAt,
      );
      final today = DateTime(2026, 5, 10);

      expect(item.daysLeftAt(today), -2);
    });

    test('daysLeftAt correctly handles leap years', () {
      final leapYearItem = PantryItem(
        name: 'Eggs',
        expiryDate: DateTime(2024, 3, 1),
        addedAt: baseAddedAt,
      );
      // In 2024 (leap year), Feb 29 exists, so difference from Feb 28 to Mar 1 is 2 days.
      expect(leapYearItem.daysLeftAt(DateTime(2024, 2, 28)), 2);

      final nonLeapYearItem = PantryItem(
        name: 'Eggs',
        expiryDate: DateTime(2023, 3, 1),
        addedAt: baseAddedAt,
      );
      // In 2023 (non-leap year), difference from Feb 28 to Mar 1 is 1 day.
      expect(nonLeapYearItem.daysLeftAt(DateTime(2023, 2, 28)), 1);
    });

    test('daysLeftAt calculates calendar day differences without DST drift', () {
      // In regions with DST, a 23-hour or 25-hour day would cause integer division by 24h
      // to produce off-by-one errors if using local difference().
      // Using UTC dates eliminates timezone transition variance.
      final item = PantryItem(
        name: 'Yogurt',
        expiryDate: DateTime(2026, 3, 10),
        addedAt: baseAddedAt,
      );
      final beforeDst = DateTime(2026, 3, 7);

      expect(item.daysLeftAt(beforeDst), 3);
    });

    group('freshnessAt', () {
      final today = DateTime(2026, 5, 10);

      test('returns expired when daysLeft is negative', () {
        final item = PantryItem(
          name: 'Expired milk',
          expiryDate: DateTime(2026, 5, 9),
          addedAt: baseAddedAt,
        );
        expect(item.freshnessAt(today), Freshness.expired);
      });

      test('returns useSoon when daysLeft is between 0 and 3', () {
        for (final days in [0, 1, 2, 3]) {
          final item = PantryItem(
            name: 'Expiring soon',
            expiryDate: today.add(Duration(days: days)),
            addedAt: baseAddedAt,
          );
          expect(
            item.freshnessAt(today),
            Freshness.useSoon,
            reason: 'Failed for $days days left',
          );
        }
      });

      test('returns fresh when daysLeft is greater than 3', () {
        final item = PantryItem(
          name: 'Fresh apples',
          expiryDate: today.add(const Duration(days: 4)),
          addedAt: baseAddedAt,
        );
        expect(item.freshnessAt(today), Freshness.fresh);
      });
    });

    test('toMap and fromMap round-trip accurately', () {
      final item = PantryItem(
        id: 42,
        name: 'Pasta',
        quantity: 3,
        category: 'Grains',
        expiryDate: DateTime(2027, 1, 15),
        barcode: '1234567890',
        addedAt: DateTime(2026, 1, 1),
        notes: 'Gluten free',
      );

      final map = item.toMap();
      final fromMap = PantryItem.fromMap(map);

      expect(fromMap, equals(item));
      expect(map['id'], 42);
      expect(map['name'], 'Pasta');
      expect(map['quantity'], 3);
      expect(map['category'], 'Grains');
      expect(map['expiry_date'], item.expiryDate.millisecondsSinceEpoch);
      expect(map['barcode'], '1234567890');
      expect(map['added_at'], item.addedAt.millisecondsSinceEpoch);
      expect(map['notes'], 'Gluten free');
    });

    test('copyWith creates a new instance with updated fields', () {
      final item = PantryItem(
        id: 1,
        name: 'Rice',
        quantity: 2,
        category: 'Grains',
        expiryDate: DateTime(2026, 6, 1),
        addedAt: baseAddedAt,
      );

      final updated = item.copyWith(quantity: 5, category: 'Pantry');

      expect(updated.id, 1);
      expect(updated.name, 'Rice');
      expect(updated.quantity, 5);
      expect(updated.category, 'Pantry');
      expect(updated.expiryDate, DateTime(2026, 6, 1));
      expect(updated.addedAt, baseAddedAt);
    });
  });
}

