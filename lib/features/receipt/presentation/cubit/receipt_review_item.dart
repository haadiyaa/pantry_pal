import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../../domain/models/draft_item.dart';

enum DuplicateResolution {
  addAsNew,
  incrementExisting,
}

/// Presentation model for an editable row on the review screen.
class ReceiptReviewItem extends Equatable {
  const ReceiptReviewItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.priceInPaise,
    this.category = 'Other',
    this.confidence = ItemConfidence.high,
    this.isIncluded = true,
    required this.expiryDate,
    this.existingItemId,
    this.existingItemQuantity,
    this.duplicateResolution = DuplicateResolution.addAsNew,
  });

  final String id;
  final String name;
  final int quantity;
  final int? priceInPaise;
  final String category;
  final ItemConfidence confidence;
  final bool isIncluded;
  final DateTime expiryDate;
  final int? existingItemId;
  final int? existingItemQuantity;
  final DuplicateResolution duplicateResolution;

  bool get isDuplicate => existingItemId != null;
  bool get isLowConfidence => confidence == ItemConfidence.low;

  ReceiptReviewItem copyWith({
    String? id,
    String? name,
    int? quantity,
    int? Function()? priceInPaise,
    String? category,
    ItemConfidence? confidence,
    bool? isIncluded,
    DateTime? expiryDate,
    int? Function()? existingItemId,
    int? Function()? existingItemQuantity,
    DuplicateResolution? duplicateResolution,
  }) {
    return ReceiptReviewItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      priceInPaise:
          priceInPaise != null ? priceInPaise() : this.priceInPaise,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      isIncluded: isIncluded ?? this.isIncluded,
      expiryDate: expiryDate ?? this.expiryDate,
      existingItemId:
          existingItemId != null ? existingItemId() : this.existingItemId,
      existingItemQuantity: existingItemQuantity != null
          ? existingItemQuantity()
          : this.existingItemQuantity,
      duplicateResolution: duplicateResolution ?? this.duplicateResolution,
    );
  }

  PantryItem toPantryItem() {
    return PantryItem(
      name: name,
      quantity: quantity,
      category: category,
      expiryDate: expiryDate,
      priceInPaise: priceInPaise,
      addedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        quantity,
        priceInPaise,
        category,
        confidence,
        isIncluded,
        expiryDate,
        existingItemId,
        existingItemQuantity,
        duplicateResolution,
      ];
}

