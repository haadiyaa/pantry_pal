import 'package:equatable/equatable.dart';

import '../../domain/models/grouped_shopping_list.dart';
import '../../domain/models/shopping_item.dart';

enum ShoppingListStatus { initial, loading, success, failure }

class ShoppingListState extends Equatable {
  const ShoppingListState({
    this.status = ShoppingListStatus.initial,
    this.items = const [],
    this.groupedList = const GroupedShoppingList.empty(),
    this.lastDeletedItem,
    this.lastClearedBought,
    this.pantryWarningItem,
    this.errorMessage,
  });

  final ShoppingListStatus status;
  final List<ShoppingItem> items;
  final GroupedShoppingList groupedList;
  final ShoppingItem? lastDeletedItem;
  final List<ShoppingItem>? lastClearedBought;
  final ShoppingItem? pantryWarningItem;
  final String? errorMessage;

  bool get isLoading => status == ShoppingListStatus.loading;
  bool get isSuccess => status == ShoppingListStatus.success;
  bool get isFailure => status == ShoppingListStatus.failure;

  int get uncheckedCount => groupedList.uncheckedCount;
  int get boughtCount => groupedList.boughtCount;
  int get totalCount => groupedList.totalCount;
  bool get isEmpty => groupedList.isEmpty;
  bool get isEverythingBought => groupedList.isEverythingBought;

  ShoppingListState copyWith({
    ShoppingListStatus? status,
    List<ShoppingItem>? items,
    GroupedShoppingList? groupedList,
    ShoppingItem? Function()? lastDeletedItem,
    List<ShoppingItem>? Function()? lastClearedBought,
    ShoppingItem? Function()? pantryWarningItem,
    String? Function()? errorMessage,
  }) {
    return ShoppingListState(
      status: status ?? this.status,
      items: items ?? this.items,
      groupedList: groupedList ?? this.groupedList,
      lastDeletedItem:
          lastDeletedItem != null ? lastDeletedItem() : this.lastDeletedItem,
      lastClearedBought: lastClearedBought != null
          ? lastClearedBought()
          : this.lastClearedBought,
      pantryWarningItem: pantryWarningItem != null
          ? pantryWarningItem()
          : this.pantryWarningItem,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        groupedList,
        lastDeletedItem,
        lastClearedBought,
        pantryWarningItem,
        errorMessage,
      ];
}

