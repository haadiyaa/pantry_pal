import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/models/product.dart';
import '../../domain/repositories/product_lookup_repository.dart';
import '../datasources/open_food_facts_api.dart';

class ProductLookupException implements Exception {
  const ProductLookupException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CachedProductLookupRepository implements ProductLookupRepository {
  const CachedProductLookupRepository({
    required this.appDb,
    required this.api,
  });

  final AppDatabase appDb;
  final OpenFoodFactsApi api;

  static const _cacheDuration = Duration(days: 30);

  @override
  Future<Product?> lookupProduct(String barcode) async {
    final db = await appDb.database;

    // 1. Check local cache
    final cachedRows = await db.query(
      AppDatabase.tableProductCache,
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );

    final Map<String, Object?>? cachedEntry =
        cachedRows.isNotEmpty ? cachedRows.first : null;

    if (cachedEntry != null) {
      final fetchedAtMs = cachedEntry['fetched_at'] as int;
      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(fetchedAtMs);
      final isFresh = DateTime.now().difference(fetchedAt) < _cacheDuration;

      // Return immediately if cache is younger than 30 days
      if (isFresh) {
        return Product.fromMap(cachedEntry);
      }
    }

    // 2. Fetch from network
    try {
      final product = await api.getProduct(barcode);

      if (product != null) {
        // Save/update cache with current timestamp
        await db.insert(
          AppDatabase.tableProductCache,
          product.toMap(fetchedAt: DateTime.now().millisecondsSinceEpoch),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return product;
      }

      // Open Food Facts confirmed product not found
      return null;
    } catch (e) {
      // 3. Fallback to stale cache if available when network fails
      if (cachedEntry != null) {
        return Product.fromMap(cachedEntry);
      }

      debugPrint('Open Food Facts API error for barcode "$barcode": $e');

      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          throw const ProductLookupException(
            'Connection timed out. Open Food Facts server took too long to respond.',
          );
        }
        final details = e.message ?? e.error?.toString() ?? e.type.name;
        throw ProductLookupException(
          'Network error ($details). Check your internet connection.',
        );
      }

      throw ProductLookupException(
        'Unable to look up product: $e',
      );
    }
  }
}
