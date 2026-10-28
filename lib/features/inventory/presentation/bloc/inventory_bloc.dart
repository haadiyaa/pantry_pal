import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc(this._repository) : super(const InventoryState()) {
    on<InventoryStarted>((event, emit) => _refresh(emit));
    on<InventoryItemAdded>(_onItemAdded);
    on<InventoryItemUpdated>(_onItemUpdated);
    on<InventoryItemDeleted>(_onItemDeleted);
  }

  final PantryRepository _repository;

  Future<void> _onItemAdded(
    InventoryItemAdded event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.add(event.item);
      await _refresh(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onItemUpdated(
    InventoryItemUpdated event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.update(event.item);
      await _refresh(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onItemDeleted(
    InventoryItemDeleted event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.delete(event.id);
      await _refresh(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _refresh(Emitter<InventoryState> emit) async {
    if (state.status == InventoryStatus.initial) {
      emit(state.copyWith(status: InventoryStatus.loading));
    }
    try {
      final items = await _repository.getAll();
      emit(
        state.copyWith(
          status: InventoryStatus.success,
          items: items,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

