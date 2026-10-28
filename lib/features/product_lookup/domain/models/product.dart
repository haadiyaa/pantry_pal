import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    required this.barcode,
    required this.name,
    this.brand,
    required this.category,
    this.imageUrl,
    this.quantity,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String category;
  final String? imageUrl;
  final String? quantity;

  Map<String, Object?> toMap({int? fetchedAt}) => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'category': category,
        'image_url': imageUrl,
        'quantity': quantity,
        'fetched_at': ?fetchedAt,
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        barcode: map['barcode'] as String,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        category: map['category'] as String,
        imageUrl: map['image_url'] as String?,
        quantity: map['quantity'] as String?,
      );

  @override
  List<Object?> get props => [
        barcode,
        name,
        brand,
        category,
        imageUrl,
        quantity,
      ];
}
