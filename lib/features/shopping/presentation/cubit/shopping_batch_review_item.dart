import 'package:equatable/equatable.dart';

/// Presentation model for an item in the batch review screen before moving to pantry.
class ShoppingBatchReviewItem extends Equatable {
  const ShoppingBatchReviewItem({
    required this.shoppingItemId,
    required this.name,
    this.quantity = 1,
    this.category = 'Other',
    required this.expiryDate,
    this.isIncluded = true,
    this.isEstimated = true,
  });

  final int shoppingItemId;
  final String name;
  final int quantity;
  final String category;
  final DateTime expiryDate;
  final bool isIncluded;
  final bool isEstimated;

  ShoppingBatchReviewItem copyWith({
    int? shoppingItemId,
    String? name,
    int? quantity,
    String? category,
    DateTime? expiryDate,
    bool? isIncluded,
    bool? isEstimated,
  }) {
    return ShoppingBatchReviewItem(
      shoppingItemId: shoppingItemId ?? this.shoppingItemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      isIncluded: isIncluded ?? this.isIncluded,
      isEstimated: isEstimated ?? this.isEstimated,
    );
  }

  @override
  List<Object?> get props => [
        shoppingItemId,
        name,
        quantity,
        category,
        expiryDate,
        isIncluded,
        isEstimated,
      ];
}

