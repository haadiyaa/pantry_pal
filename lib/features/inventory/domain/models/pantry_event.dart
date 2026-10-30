import 'package:equatable/equatable.dart';

import 'pantry_event_reason.dart';

/// Immutable model representing an event logged when an item is consumed or removed.
/// Used by waste statistics in Step 8.
class PantryEvent extends Equatable {
  const PantryEvent({
    this.id,
    required this.itemName,
    required this.category,
    this.quantity = 1,
    this.pricePaise,
    this.expiryDate,
    required this.reason,
    required this.occurredAt,
  });

  final int? id;
  final String itemName;
  final String category;
  final int quantity;
  final int? pricePaise;
  final DateTime? expiryDate;
  final PantryEventReason reason;
  final DateTime occurredAt;

  PantryEvent copyWith({
    int? id,
    String? itemName,
    String? category,
    int? quantity,
    int? pricePaise,
    DateTime? expiryDate,
    PantryEventReason? reason,
    DateTime? occurredAt,
  }) {
    return PantryEvent(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      pricePaise: pricePaise ?? this.pricePaise,
      expiryDate: expiryDate ?? this.expiryDate,
      reason: reason ?? this.reason,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'item_name': itemName,
      'category': category,
      'quantity': quantity,
      'price_paise': pricePaise,
      'expiry_date': expiryDate?.millisecondsSinceEpoch,
      'reason': reason.storageKey,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
    };
  }

  factory PantryEvent.fromMap(Map<String, Object?> map) {
    return PantryEvent(
      id: map['id'] as int?,
      itemName: map['item_name'] as String,
      category: map['category'] as String,
      quantity: (map['quantity'] as int?) ?? 1,
      pricePaise: map['price_paise'] as int?,
      expiryDate: map['expiry_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expiry_date'] as int)
          : null,
      reason: PantryEventReason.fromStorageKey(map['reason'] as String),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(map['occurred_at'] as int),
    );
  }

  @override
  List<Object?> get props => [
        id,
        itemName,
        category,
        quantity,
        pricePaise,
        expiryDate,
        reason,
        occurredAt,
      ];
}

