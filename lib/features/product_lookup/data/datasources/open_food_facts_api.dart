import 'package:dio/dio.dart';

import '../../domain/models/product.dart';
import '../../domain/utils/category_mapper.dart';

class OpenFoodFactsApi {
  OpenFoodFactsApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://world.openfoodfacts.org/api/v2/product',
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                headers: {
                  'User-Agent':
                      'PantryPal - Flutter - Version 1.0.0 - https://github.com/hadiya/pantry_pal',
                },
              ),
            );

  final Dio _dio;

  Future<Product?> getProduct(String barcode) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/$barcode.json',
      queryParameters: {
        'fields': 'code,product_name,brands,categories_tags,image_url,quantity',
      },
    );

    final data = response.data;
    if (data == null) return null;

    final status = data['status'];
    final productData = data['product'] as Map<String, dynamic>?;

    if (status == 0 || productData == null) {
      return null;
    }

    final rawName = (productData['product_name'] ??
            productData['product_name_en'] ??
            '') as String;

    final categoryTags = (productData['categories_tags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final mappedCategory = mapOpenFoodFactsCategory(categoryTags);

    return Product(
      barcode: barcode,
      name: rawName.trim().isNotEmpty ? rawName.trim() : 'Unnamed Product',
      brand: productData['brands'] as String?,
      category: mappedCategory,
      imageUrl: productData['image_url'] as String?,
      quantity: productData['quantity'] as String?,
    );
  }
}

