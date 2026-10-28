import '../models/product.dart';

/// Abstract repository for product information lookups.
abstract class ProductLookupRepository {
  /// Looks up a product by its barcode.
  /// Returns null if the barcode is not found in Open Food Facts.
  /// Throws an exception on network failure when no cached entry is available.
  Future<Product?> lookupProduct(String barcode);
}
