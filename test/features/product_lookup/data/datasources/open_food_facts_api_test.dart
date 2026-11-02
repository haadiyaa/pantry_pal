import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/product_lookup/data/datasources/open_food_facts_api.dart';

void main() {
  group('OpenFoodFactsApi Security & Validation', () {
    late OpenFoodFactsApi api;

    setUp(() {
      api = OpenFoodFactsApi();
    });

    test('rejects empty, oversized, or invalid character barcodes early without network call', () async {
      expect(await api.getProduct(''), isNull);
      expect(await api.getProduct('   '), isNull);
      // Exceeds 48 chars
      expect(await api.getProduct('1' * 50), isNull);
      // Malicious / script / path injection characters
      expect(await api.getProduct('890123; DROP TABLE pantry_items;'), isNull);
      expect(await api.getProduct('../../etc/passwd'), isNull);
      expect(await api.getProduct('<script>alert(1)</script>'), isNull);
    });
  });
}

