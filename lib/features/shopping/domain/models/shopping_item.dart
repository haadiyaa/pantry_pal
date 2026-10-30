import 'package:equatable/equatable.dart';

import 'shopping_source_type.dart';

/// Immutable model representing an item on the shopping list.
class ShoppingItem extends Equatable {
  const ShoppingItem({
    this.id,
    required this.name,
    required this.normalizedName,
    this.quantity = 1,
    this.category = 'Other',
    this.isBought = false,
    this.sourceType = ShoppingSourceType.manual,
    this.sourceLabel,
    required this.addedAt,
    this.boughtAt,
  });

  final int? id;
  final String name;
  final String normalizedName;
  final int quantity;
  final String category;
  final bool isBought;
  final ShoppingSourceType sourceType;
  final String? sourceLabel;
  final DateTime addedAt;
  final DateTime? boughtAt;

  ShoppingItem copyWith({
    int? id,
    String? name,
    String? normalizedName,
    int? quantity,
    String? category,
    bool? isBought,
    ShoppingSourceType? sourceType,
    String? sourceLabel,
    DateTime? addedAt,
    DateTime? boughtAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      isBought: isBought ?? this.isBought,
      sourceType: sourceType ?? this.sourceType,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      addedAt: addedAt ?? this.addedAt,
      boughtAt: boughtAt ?? this.boughtAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'normalized_name': normalizedName,
      'quantity': quantity,
      'category': category,
      'is_bought': isBought ? 1 : 0,
      'source_type': sourceType.storageKey,
      'source_label': sourceLabel,
      'added_at': addedAt.millisecondsSinceEpoch,
      'bought_at': boughtAt?.millisecondsSinceEpoch,
    };
  }

  factory ShoppingItem.fromMap(Map<String, Object?> map) {
    return ShoppingItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      normalizedName: map['normalized_name'] as String,
      quantity: (map['quantity'] as int?) ?? 1,
      category: (map['category'] as String?) ?? 'Other',
      isBought: (map['is_bought'] as int?) == 1,
      sourceType: ShoppingSourceType.fromStorageKey(
        (map['source_type'] as String?) ?? 'manual',
      ),
      sourceLabel: map['source_label'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
      boughtAt: map['bought_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['bought_at'] as int)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        normalizedName,
        quantity,
        category,
        isBought,
        sourceType,
        sourceLabel,
        addedAt,
        boughtAt,
      ];
}

