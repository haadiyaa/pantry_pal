part of 'product_lookup_bloc.dart';

sealed class ProductLookupState extends Equatable {
  const ProductLookupState();

  @override
  List<Object?> get props => [];
}

final class ProductLookupInitial extends ProductLookupState {
  const ProductLookupInitial();
}

final class ProductLookupLoading extends ProductLookupState {
  const ProductLookupLoading(this.barcode);
  final String barcode;

  @override
  List<Object?> get props => [barcode];
}

final class ProductLookupFound extends ProductLookupState {
  const ProductLookupFound({
    required this.product,
    this.existingItem,
  });

  final Product product;
  final PantryItem? existingItem;

  bool get alreadyInPantry => existingItem != null;

  @override
  List<Object?> get props => [product, existingItem];
}

final class ProductLookupNotFound extends ProductLookupState {
  const ProductLookupNotFound(this.barcode);
  final String barcode;

  @override
  List<Object?> get props => [barcode];
}

final class ProductLookupFailure extends ProductLookupState {
  const ProductLookupFailure({
    required this.message,
    required this.barcode,
  });

  final String message;
  final String barcode;

  @override
  List<Object?> get props => [message, barcode];
}

final class ProductLookupActionCompleted extends ProductLookupState {
  const ProductLookupActionCompleted();
}

