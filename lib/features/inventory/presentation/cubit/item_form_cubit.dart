import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/pantry_category.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';
import 'item_form_state.dart';

class ItemFormCubit extends Cubit<ItemFormState> {
  ItemFormCubit({
    required this.repository,
    PantryItem? initialItem,
  }) : super(ItemFormState.fromItem(initialItem));

  final PantryRepository repository;

  void nameChanged(String value) {
    String? error;
    final trimmed = value.trim();
    if (trimmed.length > 100) {
      error = 'Name cannot exceed 100 characters';
    } else if (state.nameError != null && trimmed.isNotEmpty) {
      error = null;
    } else {
      error = state.nameError;
    }
    emit(state.copyWith(
      name: value,
      nameError: () => error,
    ));
  }

  void quantityChanged(int value) {
    String? error;
    if (value < 1) {
      error = 'Quantity must be at least 1';
    } else if (value > 9999) {
      error = 'Quantity cannot exceed 9,999';
    }
    emit(state.copyWith(
      quantity: value,
      quantityError: () => error,
    ));
  }

  void quantityIncremented() {
    if (state.quantity < 9999) {
      emit(state.copyWith(
        quantity: state.quantity + 1,
        quantityError: () => null,
      ));
    }
  }

  void quantityDecremented() {
    if (state.quantity > 1) {
      emit(state.copyWith(
        quantity: state.quantity - 1,
        quantityError: () => null,
      ));
    }
  }

  void categoryChanged(PantryCategory value) {
    emit(state.copyWith(category: value));
  }

  void expiryDateChanged(DateTime value) {
    emit(state.copyWith(expiryDate: value));
  }

  void barcodeChanged(String value) {
    emit(state.copyWith(barcode: value));
  }

  void notesChanged(String value) {
    emit(state.copyWith(notes: value));
  }

  void priceChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(
        priceText: value,
        priceInPaise: () => null,
        priceError: () => null,
      ));
      return;
    }

    final normalized = trimmed.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      emit(state.copyWith(
        priceText: value,
        priceInPaise: () => null,
        priceError: () => 'Enter a valid price (e.g. 45.50)',
      ));
      return;
    }

    if (parsed > 100000) {
      emit(state.copyWith(
        priceText: value,
        priceInPaise: () => null,
        priceError: () => 'Price cannot exceed ₹1,00,000',
      ));
      return;
    }

    final parts = normalized.split('.');
    if (parts.length > 1 && parts[1].length > 2) {
      emit(state.copyWith(
        priceText: value,
        priceInPaise: () => null,
        priceError: () => 'Price can have at most 2 decimal places',
      ));
      return;
    }

    final paise = (parsed * 100).round();
    emit(state.copyWith(
      priceText: value,
      priceInPaise: () => paise,
      priceError: () => null,
    ));
  }

  Future<void> submit() async {
    final trimmedName = state.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(
        nameError: () => 'Item name is required',
      ));
      return;
    }

    if (trimmedName.length > 100) {
      emit(state.copyWith(
        nameError: () => 'Name cannot exceed 100 characters',
      ));
      return;
    }

    if (state.quantity < 1) {
      emit(state.copyWith(
        quantityError: () => 'Quantity must be at least 1',
      ));
      return;
    }

    if (state.quantity > 9999) {
      emit(state.copyWith(
        quantityError: () => 'Quantity cannot exceed 9,999',
      ));
      return;
    }

    if (state.priceError != null) {
      return;
    }

    emit(state.copyWith(
      nameError: () => null,
      quantityError: () => null,
      priceError: () => null,
      status: ItemFormStatus.submitting,
    ));

    try {
      final rawBarcode = state.barcode.trim();
      final barcode = rawBarcode.length > 48
          ? rawBarcode.substring(0, 48)
          : rawBarcode;
      final rawNotes = state.notes.trim();
      final notes =
          rawNotes.length > 500 ? rawNotes.substring(0, 500) : rawNotes;

      if (state.isEditing) {
        final updated = state.initialItem!.copyWith(
          name: trimmedName,
          quantity: state.quantity,
          category: state.category.label,
          expiryDate: state.expiryDate,
          barcode: barcode.isEmpty ? null : barcode,
          notes: notes.isEmpty ? null : notes,
          priceInPaise: state.priceInPaise,
        );
        await repository.update(updated);
      } else {
        final newItem = PantryItem(
          name: trimmedName,
          quantity: state.quantity,
          category: state.category.label,
          expiryDate: state.expiryDate,
          barcode: barcode.isEmpty ? null : barcode,
          notes: notes.isEmpty ? null : notes,
          addedAt: DateTime.now(),
          priceInPaise: state.priceInPaise,
        );
        await repository.add(newItem);
      }

      emit(state.copyWith(status: ItemFormStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: ItemFormStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
