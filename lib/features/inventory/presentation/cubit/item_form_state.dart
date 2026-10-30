import 'package:equatable/equatable.dart';

import '../../domain/models/pantry_category.dart';
import '../../domain/models/pantry_item.dart';

enum ItemFormStatus { initial, submitting, success, failure }

class ItemFormState extends Equatable {
  const ItemFormState({
    this.initialItem,
    this.name = '',
    this.quantity = 1,
    this.category = PantryCategory.other,
    required this.expiryDate,
    this.barcode = '',
    this.notes = '',
    this.priceText = '',
    this.priceInPaise,
    this.nameError,
    this.quantityError,
    this.priceError,
    this.status = ItemFormStatus.initial,
    this.errorMessage,
  });

  factory ItemFormState.fromItem(PantryItem? item) {
    final now = DateTime.now();
    final initialPriceText = item?.priceInPaise != null
        ? (item!.priceInPaise! / 100)
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'\.00$'), '')
        : '';

    return ItemFormState(
      initialItem: item,
      name: item?.name ?? '',
      quantity: item?.quantity ?? 1,
      category: PantryCategory.fromString(item?.category),
      expiryDate: item?.expiryDate ?? now.add(const Duration(days: 7)),
      barcode: item?.barcode ?? '',
      notes: item?.notes ?? '',
      priceText: initialPriceText,
      priceInPaise: item?.priceInPaise,
      nameError: null,
      quantityError: null,
      priceError: null,
      status: ItemFormStatus.initial,
      errorMessage: null,
    );
  }

  final PantryItem? initialItem;
  final String name;
  final int quantity;
  final PantryCategory category;
  final DateTime expiryDate;
  final String barcode;
  final String notes;
  final String priceText;
  final int? priceInPaise;
  final String? nameError;
  final String? quantityError;
  final String? priceError;
  final ItemFormStatus status;
  final String? errorMessage;

  bool get isEditing => initialItem?.id != null;

  ItemFormState copyWith({
    PantryItem? initialItem,
    String? name,
    int? quantity,
    PantryCategory? category,
    DateTime? expiryDate,
    String? barcode,
    String? notes,
    String? priceText,
    int? Function()? priceInPaise,
    String? Function()? nameError,
    String? Function()? quantityError,
    String? Function()? priceError,
    ItemFormStatus? status,
    String? errorMessage,
  }) {
    return ItemFormState(
      initialItem: initialItem ?? this.initialItem,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      barcode: barcode ?? this.barcode,
      notes: notes ?? this.notes,
      priceText: priceText ?? this.priceText,
      priceInPaise:
          priceInPaise != null ? priceInPaise() : this.priceInPaise,
      nameError: nameError != null ? nameError() : this.nameError,
      quantityError:
          quantityError != null ? quantityError() : this.quantityError,
      priceError: priceError != null ? priceError() : this.priceError,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        initialItem,
        name,
        quantity,
        category,
        expiryDate,
        barcode,
        notes,
        priceText,
        priceInPaise,
        nameError,
        quantityError,
        priceError,
        status,
        errorMessage,
      ];
}
