import 'package:equatable/equatable.dart';

import '../../../../core/ui/ui_message.dart';
import '../../domain/models/grouped_shopping_list.dart';
import '../../domain/models/shopping_item.dart';

enum ShoppingListStatus { initial, loading, success, failure }

class ShoppingListState extends Equatable {
  const ShoppingListState({
    this.status = ShoppingListStatus.initial,
    this.items = const [],
    this.groupedList = const GroupedShoppingList.empty(),
    this.uiMessage,
    ShoppingItem? lastDeletedItem,
    List<ShoppingItem>? lastClearedBought,
    this.pantryWarningItem,
    this.errorMessage,
    // ignore: prefer_initializing_formals - parameters preserve public names for backwards compatibility.
  })  : _lastDeletedItem = lastDeletedItem,
        // ignore: prefer_initializing_formals - parameter preserves public name for backwards compatibility.
        _lastClearedBought = lastClearedBought;

  final ShoppingListStatus status;
  final List<ShoppingItem> items;
  final GroupedShoppingList groupedList;

  /// One-shot UI notification message with unique ID.
  final UiMessage<dynamic>? uiMessage;

  final ShoppingItem? _lastDeletedItem;
  final List<ShoppingItem>? _lastClearedBought;

  ShoppingItem? get lastDeletedItem =>
      uiMessage?.payload is ShoppingItem ? (uiMessage!.payload as ShoppingItem) : _lastDeletedItem;

  List<ShoppingItem>? get lastClearedBought =>
      uiMessage?.payload is List<ShoppingItem>
          ? (uiMessage!.payload as List<ShoppingItem>)
          : _lastClearedBought;

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
    UiMessage<dynamic>? Function()? uiMessage,
    ShoppingItem? Function()? lastDeletedItem,
    List<ShoppingItem>? Function()? lastClearedBought,
    ShoppingItem? Function()? pantryWarningItem,
    String? Function()? errorMessage,
  }) {
    UiMessage<dynamic>? nextUiMessage;
    if (uiMessage != null) {
      nextUiMessage = uiMessage();
    } else if (lastDeletedItem != null) {
      final item = lastDeletedItem();
      nextUiMessage = item != null
          ? UiMessage<ShoppingItem>.create(
              text: 'Deleted "${item.name}"',
              type: UiMessageType.undo,
              actionLabel: 'Undo',
              payload: item,
            )
          : null;
    } else if (lastClearedBought != null) {
      final items = lastClearedBought();
      nextUiMessage = items != null && items.isNotEmpty
          ? UiMessage<List<ShoppingItem>>.create(
              text: 'Cleared ${items.length} bought items',
              type: UiMessageType.undo,
              actionLabel: 'Undo',
              payload: items,
            )
          : null;
    } else {
      nextUiMessage = this.uiMessage;
    }

    return ShoppingListState(
      status: status ?? this.status,
      items: items ?? this.items,
      groupedList: groupedList ?? this.groupedList,
      uiMessage: nextUiMessage,
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
        uiMessage,
        pantryWarningItem,
        errorMessage,
      ];
}

