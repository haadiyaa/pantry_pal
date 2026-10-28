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

final class InventorySearchChanged extends InventoryEvent {
  const InventorySearchChanged(this.query);
  final String query;

  @override
  List<Object?> get props => [query];
}

final class InventoryCategoryToggled extends InventoryEvent {
  const InventoryCategoryToggled(this.category);
  final String category;

  @override
  List<Object?> get props => [category];
}

final class InventoryExpiringFilterToggled extends InventoryEvent {
  const InventoryExpiringFilterToggled();
}

final class InventoryFiltersCleared extends InventoryEvent {
  const InventoryFiltersCleared();
}
