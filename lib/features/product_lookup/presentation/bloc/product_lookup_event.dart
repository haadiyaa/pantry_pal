part of 'product_lookup_bloc.dart';

sealed class ProductLookupEvent extends Equatable {
  const ProductLookupEvent();

  @override
  List<Object?> get props => [];
}

final class ProductLookupBarcodeScanned extends ProductLookupEvent {
  const ProductLookupBarcodeScanned(this.barcode);
  final String barcode;

  @override
  List<Object?> get props => [barcode];
}

final class ProductLookupIncreaseQuantity extends ProductLookupEvent {
  const ProductLookupIncreaseQuantity(this.existingItem);
  final PantryItem existingItem;

  @override
  List<Object?> get props => [existingItem];
}

final class ProductLookupReset extends ProductLookupEvent {
  const ProductLookupReset();
}

