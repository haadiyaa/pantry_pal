import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/models/pantry_item.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/product_lookup/domain/models/product.dart';
import 'package:pantry_pal/features/product_lookup/domain/repositories/product_lookup_repository.dart';
import 'package:pantry_pal/features/product_lookup/presentation/bloc/product_lookup_bloc.dart';

class MockProductLookupRepository extends Mock
    implements ProductLookupRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

class FakePantryItem extends Fake implements PantryItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakePantryItem());
  });

  late MockProductLookupRepository productRepository;
  late MockPantryRepository pantryRepository;

  const testBarcode = '737628064502';
  const testProduct = Product(
    barcode: testBarcode,
    name: 'Thai Peanut Sauce',
    brand: 'San-J',
    category: 'Snacks',
    imageUrl: 'https://example.com/sauce.jpg',
    quantity: '296 ml',
  );

  final existingPantryItem = PantryItem(
    id: 9,
    name: 'Thai Peanut Sauce',
    quantity: 1,
    category: 'Snacks',
    barcode: testBarcode,
    expiryDate: DateTime(2026, 10, 1),
    addedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    productRepository = MockProductLookupRepository();
    pantryRepository = MockPantryRepository();
  });

  group('ProductLookupBloc', () {
    test('initial state is ProductLookupInitial', () {
      final bloc = ProductLookupBloc(
        productRepository: productRepository,
        pantryRepository: pantryRepository,
      );
      expect(bloc.state, const ProductLookupInitial());
    });

    group('ProductLookupBarcodeScanned', () {
      blocTest<ProductLookupBloc, ProductLookupState>(
        'emits [loading, found] without existing item when not yet in pantry',
        build: () {
          when(() => productRepository.lookupProduct(testBarcode))
              .thenAnswer((_) async => testProduct);
          when(() => pantryRepository.getByBarcode(testBarcode))
              .thenAnswer((_) async => null);
          return ProductLookupBloc(
            productRepository: productRepository,
            pantryRepository: pantryRepository,
          );
        },
        act: (bloc) =>
            bloc.add(const ProductLookupBarcodeScanned(testBarcode)),
        expect: () => [
          const ProductLookupLoading(testBarcode),
          const ProductLookupFound(product: testProduct, existingItem: null),
        ],
        verify: (_) {
          verify(() => productRepository.lookupProduct(testBarcode)).called(1);
          verify(() => pantryRepository.getByBarcode(testBarcode)).called(1);
        },
      );

      blocTest<ProductLookupBloc, ProductLookupState>(
        'emits [loading, found] with existing item when barcode is already in pantry',
        build: () {
          when(() => productRepository.lookupProduct(testBarcode))
              .thenAnswer((_) async => testProduct);
          when(() => pantryRepository.getByBarcode(testBarcode))
              .thenAnswer((_) async => existingPantryItem);
          return ProductLookupBloc(
            productRepository: productRepository,
            pantryRepository: pantryRepository,
          );
        },
        act: (bloc) =>
            bloc.add(const ProductLookupBarcodeScanned(testBarcode)),
        expect: () => [
          const ProductLookupLoading(testBarcode),
          ProductLookupFound(
            product: testProduct,
            existingItem: existingPantryItem,
          ),
        ],
      );

      blocTest<ProductLookupBloc, ProductLookupState>(
        'emits [loading, notFound] when product is null in Open Food Facts',
        build: () {
          when(() => productRepository.lookupProduct(testBarcode))
              .thenAnswer((_) async => null);
          return ProductLookupBloc(
            productRepository: productRepository,
            pantryRepository: pantryRepository,
          );
        },
        act: (bloc) =>
            bloc.add(const ProductLookupBarcodeScanned(testBarcode)),
        expect: () => [
          const ProductLookupLoading(testBarcode),
          const ProductLookupNotFound(testBarcode),
        ],
      );

      blocTest<ProductLookupBloc, ProductLookupState>(
        'emits [loading, failure] when lookup throws an exception',
        build: () {
          when(() => productRepository.lookupProduct(testBarcode))
              .thenThrow(Exception('Network timeout'));
          return ProductLookupBloc(
            productRepository: productRepository,
            pantryRepository: pantryRepository,
          );
        },
        act: (bloc) =>
            bloc.add(const ProductLookupBarcodeScanned(testBarcode)),
        expect: () => [
          const ProductLookupLoading(testBarcode),
          const ProductLookupFailure(
            message: 'Network timeout',
            barcode: testBarcode,
          ),
        ],
      );
    });

    group('ProductLookupIncreaseQuantity', () {
      blocTest<ProductLookupBloc, ProductLookupState>(
        'updates existing item with incremented quantity and emits ProductLookupActionCompleted',
        build: () {
          when(() => pantryRepository.update(any())).thenAnswer((_) async {});
          return ProductLookupBloc(
            productRepository: productRepository,
            pantryRepository: pantryRepository,
          );
        },
        act: (bloc) =>
            bloc.add(ProductLookupIncreaseQuantity(existingPantryItem)),
        expect: () => [
          const ProductLookupActionCompleted(),
        ],
        verify: (_) {
          verify(
            () => pantryRepository.update(
              any(
                that: isA<PantryItem>()
                    .having((i) => i.id, 'id', 9)
                    .having((i) => i.quantity, 'quantity', 2),
              ),
            ),
          ).called(1);
        },
      );
    });

    group('ProductLookupReset', () {
      blocTest<ProductLookupBloc, ProductLookupState>(
        'resets state back to ProductLookupInitial',
        build: () => ProductLookupBloc(
          productRepository: productRepository,
          pantryRepository: pantryRepository,
        ),
        seed: () => const ProductLookupNotFound(testBarcode),
        act: (bloc) => bloc.add(const ProductLookupReset()),
        expect: () => [
          const ProductLookupInitial(),
        ],
      );
    });
  });
}

