import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../domain/models/product.dart';
import '../../domain/repositories/product_lookup_repository.dart';

part 'product_lookup_event.dart';
part 'product_lookup_state.dart';

class ProductLookupBloc extends Bloc<ProductLookupEvent, ProductLookupState> {
  ProductLookupBloc({
    required this.productRepository,
    required this.pantryRepository,
  }) : super(const ProductLookupInitial()) {
    on<ProductLookupBarcodeScanned>(_onBarcodeScanned);
    on<ProductLookupIncreaseQuantity>(_onIncreaseQuantity);
    on<ProductLookupReset>(_onReset);
  }

  final ProductLookupRepository productRepository;
  final PantryRepository pantryRepository;

  Future<void> _onBarcodeScanned(
    ProductLookupBarcodeScanned event,
    Emitter<ProductLookupState> emit,
  ) async {
    emit(ProductLookupLoading(event.barcode));

    try {
      final product = await productRepository.lookupProduct(event.barcode);
      if (product == null) {
        emit(ProductLookupNotFound(event.barcode));
        return;
      }

      // Check if product is already tracked in pantry
      final existingItem =
          await pantryRepository.getByBarcode(event.barcode);

      emit(ProductLookupFound(
        product: product,
        existingItem: existingItem,
      ));
    } catch (e) {
      emit(ProductLookupFailure(
        message: e.toString().replaceFirst('Exception: ', ''),
        barcode: event.barcode,
      ));
    }
  }

  Future<void> _onIncreaseQuantity(
    ProductLookupIncreaseQuantity event,
    Emitter<ProductLookupState> emit,
  ) async {
    try {
      final updated = event.existingItem.copyWith(
        quantity: event.existingItem.quantity + 1,
      );
      await pantryRepository.update(updated);
      emit(const ProductLookupActionCompleted());
    } catch (e) {
      emit(ProductLookupFailure(
        message: e.toString(),
        barcode: event.existingItem.barcode ?? '',
      ));
    }
  }

  void _onReset(
    ProductLookupReset event,
    Emitter<ProductLookupState> emit,
  ) {
    emit(const ProductLookupInitial());
  }
}
