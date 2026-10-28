part of 'inventory_bloc.dart';

sealed class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

final class InventoryStarted extends InventoryEvent {
  const InventoryStarted();
}

final class InventoryItemAdded extends InventoryEvent {
  const InventoryItemAdded(this.item);
  final PantryItem item;

  @override
  List<Object?> get props => [item];
}

final class InventoryItemUpdated extends InventoryEvent {
  const InventoryItemUpdated(this.item);
  final PantryItem item;

  @override
  List<Object?> get props => [item];
}

final class InventoryItemDeleted extends InventoryEvent {
  const InventoryItemDeleted(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

