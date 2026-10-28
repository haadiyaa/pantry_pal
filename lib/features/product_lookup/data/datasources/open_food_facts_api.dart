import 'package:dio/dio.dart';

import '../../domain/models/product.dart';
import '../../domain/utils/category_mapper.dart';

class OpenFoodFactsApi {
  OpenFoodFactsApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://world.openfoodfacts.org/api/v2/product',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                validateStatus: (status) =>
                    status != null && (status < 300 || status == 404),
                headers: {
                  'User-Agent':
                      'PantryPal - Flutter - Version 1.0.0 - https://github.com/hadiya/pantry_pal',
                },
              ),
            );

  final Dio _dio;

  Future<Product?> getProduct(String barcode) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        '/${Uri.encodeComponent(barcode)}.json',
        queryParameters: {
          'fields': 'code,product_name,brands,categories_tags,image_url,quantity',
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }

    if (response.statusCode == 404) {
      return null;
    }

    final data = response.data;
    if (data == null) return null;

    final status = data['status'];
    final productData = data['product'] as Map<String, dynamic>?;

    if (status == 0 || productData == null) {
      return null;
    }

    final rawName = (productData['product_name'] ??
            productData['product_name_en'] ??
            '')
        .toString();

    final categoryTags = (productData['categories_tags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final mappedCategory = mapOpenFoodFactsCategory(categoryTags);

    return Product(
      barcode: barcode,
      name: rawName.trim().isNotEmpty ? rawName.trim() : 'Unnamed Product',
      brand: productData['brands']?.toString(),
      category: mappedCategory,
      imageUrl: productData['image_url']?.toString(),
      quantity: productData['quantity']?.toString(),
    );
  }
}

