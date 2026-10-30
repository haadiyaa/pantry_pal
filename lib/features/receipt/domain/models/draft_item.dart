import 'package:equatable/equatable.dart';

import '../../../inventory/domain/models/pantry_item.dart';

enum ItemConfidence { high, low }

/// An item parsed from a receipt before the user confirms it in the review screen.
/// Has zero Flutter framework or ML Kit dependencies.
class DraftItem extends Equatable {
  const DraftItem({
    required this.name,
    this.quantity = 1,
    this.priceInPaise,
    this.category = 'Other',
    this.confidence = ItemConfidence.high,
    this.isIncluded = true,
    this.suggestedExpiryDate,
  });

  final String name;
  final int quantity;
  final int? priceInPaise;
  final String category;
  final ItemConfidence confidence;
  final bool isIncluded;
  final DateTime? suggestedExpiryDate;

  DraftItem copyWith({
    String? name,
    int? quantity,
    int? Function()? priceInPaise,
    String? category,
    ItemConfidence? confidence,
    bool? isIncluded,
    DateTime? Function()? suggestedExpiryDate,
  }) {
    return DraftItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      priceInPaise:
          priceInPaise != null ? priceInPaise() : this.priceInPaise,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      isIncluded: isIncluded ?? this.isIncluded,
      suggestedExpiryDate: suggestedExpiryDate != null
          ? suggestedExpiryDate()
          : this.suggestedExpiryDate,
    );
  }

  /// Converts this draft into a permanent [PantryItem].
  PantryItem toPantryItem({required DateTime fallbackExpiry}) {
    return PantryItem(
      name: name,
      quantity: quantity,
      category: category,
      expiryDate: suggestedExpiryDate ?? fallbackExpiry,
      priceInPaise: priceInPaise,
      addedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        name,
        quantity,
        priceInPaise,
        category,
        confidence,
        isIncluded,
        suggestedExpiryDate,
      ];
}

