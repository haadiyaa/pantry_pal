import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../../recipes/domain/services/ingredient_normalizer.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/models/shopping_source_type.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../../domain/services/shopping_list_grouper.dart';
import 'shopping_list_event.dart';
import 'shopping_list_state.dart';

class ShoppingListBloc extends Bloc<ShoppingListEvent, ShoppingListState> {
  ShoppingListBloc({
    required this.shoppingRepository,
    required this.pantryRepository,
    DateTime Function()? nowProvider,
  })  : _nowProvider = nowProvider ?? DateTime.now,
        super(const ShoppingListState()) {
    on<ShoppingListStarted>(_onStarted);
    on<ShoppingListManualItemAdded>(_onManualItemAdded);
    on<ShoppingListItemEdited>(_onItemEdited);
    on<ShoppingListItemDeleted>(_onItemDeleted);
    on<ShoppingListUndoDelete>(_onUndoDelete);
    on<ShoppingListItemBoughtToggled>(_onItemBoughtToggled);
    on<ShoppingListClearBought>(_onClearBought);
    on<ShoppingListUndoClearBought>(_onUndoClearBought);
    on<ShoppingListAddedFromRecipe>(_onAddedFromRecipe);
    on<ShoppingListShareRequested>(_onShareRequested);
    on<ShoppingListDismissPantryWarning>(_onDismissPantryWarning);
  }

  final ShoppingRepository shoppingRepository;
  final PantryRepository pantryRepository;
  final DateTime Function() _nowProvider;

  Future<void> _onStarted(
    ShoppingListStarted event,
    Emitter<ShoppingListState> emit,
  ) async {
    emit(state.copyWith(status: ShoppingListStatus.loading));
    await emit.forEach<List<ShoppingItem>>(
      shoppingRepository.watchAll(),
      onData: (items) {
        final grouped = ShoppingListGrouper.group(items);
        return state.copyWith(
          status: ShoppingListStatus.success,
          items: items,
          groupedList: grouped,
          errorMessage: () => null,
        );
      },
      onError: (e, _) => state.copyWith(
        status: ShoppingListStatus.failure,
        errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
      ),
    );
  }

  Future<void> _onManualItemAdded(
    ShoppingListManualItemAdded event,
    Emitter<ShoppingListState> emit,
  ) async {
    final rawName = event.name.trim();
    if (rawName.isEmpty) return;

    final normalized = IngredientNormalizer.normalize(rawName);
    final key = normalized.isNotEmpty ? normalized : rawName.toLowerCase();

    // Check if the item is already present in the user's pantry
    if (!event.forceAdd) {
      try {
        final pantryItems = await pantryRepository.getAll();
        final alreadyInPantry = pantryItems.any(
          (p) =>
              p.quantity > 0 &&
              (IngredientNormalizer.normalize(p.name) == key ||
                  p.name.toLowerCase().trim() == rawName.toLowerCase()),
        );

        if (alreadyInPantry) {
          final candidate = ShoppingItem(
            name: rawName,
            normalizedName: key,
            quantity: event.quantity,
            category: event.category,
            sourceType: ShoppingSourceType.manual,
            sourceLabel: 'Manual',
            addedAt: _nowProvider(),
          );
          emit(state.copyWith(pantryWarningItem: () => candidate));
          return;
        }
      } catch (_) {}
    }

    final item = ShoppingItem(
      name: rawName,
      normalizedName: key,
      quantity: event.quantity,
      category: event.category,
      sourceType: ShoppingSourceType.manual,
      sourceLabel: 'Manual',
      addedAt: _nowProvider(),
    );

    try {
      await shoppingRepository.add(item);
      emit(state.copyWith(pantryWarningItem: () => null));
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onItemEdited(
    ShoppingListItemEdited event,
    Emitter<ShoppingListState> emit,
  ) async {
    try {
      await shoppingRepository.update(event.item);
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onItemDeleted(
    ShoppingListItemDeleted event,
    Emitter<ShoppingListState> emit,
  ) async {
    try {
      final item = await shoppingRepository.getById(event.id);
      if (item != null) {
        await shoppingRepository.delete(event.id);
        emit(state.copyWith(lastDeletedItem: () => item));
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onUndoDelete(
    ShoppingListUndoDelete event,
    Emitter<ShoppingListState> emit,
  ) async {
    try {
      await shoppingRepository.restore(event.item);
      emit(state.copyWith(lastDeletedItem: () => null));
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onItemBoughtToggled(
    ShoppingListItemBoughtToggled event,
    Emitter<ShoppingListState> emit,
  ) async {
    try {
      await shoppingRepository.setBought(
        event.id,
        event.isBought,
        boughtAt: event.isBought ? _nowProvider() : null,
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onClearBought(
    ShoppingListClearBought event,
    Emitter<ShoppingListState> emit,
  ) async {
    try {
      final cleared = await shoppingRepository.clearBought();
      emit(state.copyWith(lastClearedBought: () => cleared));
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onUndoClearBought(
    ShoppingListUndoClearBought event,
    Emitter<ShoppingListState> emit,
  ) async {
    try {
      for (final item in event.items) {
        await shoppingRepository.restore(item);
      }
      emit(state.copyWith(lastClearedBought: () => null));
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onAddedFromRecipe(
    ShoppingListAddedFromRecipe event,
    Emitter<ShoppingListState> emit,
  ) async {
    try {
      await shoppingRepository.addAll(event.items);
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingListStatus.failure,
          errorMessage: () => e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> _onShareRequested(
    ShoppingListShareRequested event,
    Emitter<ShoppingListState> emit,
  ) async {
    final unchecked = state.groupedList.uncheckedCategories;
    if (unchecked.isEmpty) return;

    final buffer = StringBuffer('🛒 Shopping List\n\n');
    for (final entry in unchecked.entries) {
      buffer.writeln('${entry.key}:');
      for (final item in entry.value) {
        final qtyStr = item.quantity > 1 ? ' (x${item.quantity})' : '';
        buffer.writeln(' • ${item.name}$qtyStr');
      }
      buffer.writeln();
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString().trim(),
          subject: 'Pantry Pal Shopping List',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: () => 'Failed to open share sheet: $e',
        ),
      );
    }
  }

  void _onDismissPantryWarning(
    ShoppingListDismissPantryWarning event,
    Emitter<ShoppingListState> emit,
  ) {
    emit(state.copyWith(pantryWarningItem: () => null));
  }
}
