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
    final error = state.nameError != null && value.trim().isNotEmpty
        ? null
        : state.nameError;
    emit(state.copyWith(
      name: value,
      nameError: () => error,
    ));
  }

  void quantityChanged(int value) {
    emit(state.copyWith(
      quantity: value,
      quantityError: () => value < 1 ? 'Quantity must be at least 1' : null,
    ));
  }

  void quantityIncremented() {
    emit(state.copyWith(
      quantity: state.quantity + 1,
      quantityError: () => null,
    ));
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

  Future<void> submit() async {
    final trimmedName = state.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(
        nameError: () => 'Item name is required',
      ));
      return;
    }

    if (state.quantity < 1) {
      emit(state.copyWith(
        quantityError: () => 'Quantity must be at least 1',
      ));
      return;
    }

    emit(state.copyWith(
      nameError: () => null,
      quantityError: () => null,
      status: ItemFormStatus.submitting,
    ));

    try {
      final barcode = state.barcode.trim();
      final notes = state.notes.trim();

      if (state.isEditing) {
        final updated = state.initialItem!.copyWith(
          name: trimmedName,
          quantity: state.quantity,
          category: state.category.label,
          expiryDate: state.expiryDate,
          barcode: barcode.isEmpty ? null : barcode,
          notes: notes.isEmpty ? null : notes,
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
