part of 'inventory_bloc.dart';

enum InventoryStatus { initial, loading, success, failure }

final class InventoryState extends Equatable {
  const InventoryState({
    this.status = InventoryStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final InventoryStatus status;
  final List<PantryItem> items;
  final String? errorMessage;

  InventoryState copyWith({
    InventoryStatus? status,
    List<PantryItem>? items,
    String? errorMessage,
  }) {
    return InventoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
