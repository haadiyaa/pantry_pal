import 'package:equatable/equatable.dart';

import '../../domain/models/shopping_item.dart';

abstract class ShoppingListEvent extends Equatable {
  const ShoppingListEvent();

  @override
  List<Object?> get props => [];
}

class ShoppingListStarted extends ShoppingListEvent {
  const ShoppingListStarted();
}

class ShoppingListManualItemAdded extends ShoppingListEvent {
  const ShoppingListManualItemAdded({
    required this.name,
    this.category = 'Other',
    this.quantity = 1,
    this.forceAdd = false,
  });

  final String name;
  final String category;
  final int quantity;
  final bool forceAdd;

  @override
  List<Object?> get props => [name, category, quantity, forceAdd];
}

class ShoppingListItemEdited extends ShoppingListEvent {
  const ShoppingListItemEdited(this.item);
  final ShoppingItem item;

  @override
  List<Object?> get props => [item];
}

class ShoppingListItemDeleted extends ShoppingListEvent {
  const ShoppingListItemDeleted(this.id);
  final int id;

  @override
  List<Object?> get props => [id];
}

class ShoppingListUndoDelete extends ShoppingListEvent {
  const ShoppingListUndoDelete(this.item);
  final ShoppingItem item;

  @override
  List<Object?> get props => [item];
}

class ShoppingListItemBoughtToggled extends ShoppingListEvent {
  const ShoppingListItemBoughtToggled({
    required this.id,
    required this.isBought,
  });

  final int id;
  final bool isBought;

  @override
  List<Object?> get props => [id, isBought];
}

class ShoppingListClearBought extends ShoppingListEvent {
  const ShoppingListClearBought();
}

class ShoppingListUndoClearBought extends ShoppingListEvent {
  const ShoppingListUndoClearBought(this.items);
  final List<ShoppingItem> items;

  @override
  List<Object?> get props => [items];
}

class ShoppingListAddedFromRecipe extends ShoppingListEvent {
  const ShoppingListAddedFromRecipe(this.items);
  final List<ShoppingItem> items;

  @override
  List<Object?> get props => [items];
}

class ShoppingListShareRequested extends ShoppingListEvent {
  const ShoppingListShareRequested();
}

class ShoppingListDismissPantryWarning extends ShoppingListEvent {
  const ShoppingListDismissPantryWarning();
}

