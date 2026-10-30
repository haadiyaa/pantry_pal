import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../domain/models/consume_result.dart';
import '../../domain/models/pantry_event_reason.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';
import '../../../notifications/domain/services/notification_sync_service.dart';
import '../../../shopping/data/repositories/shared_preferences_shopping_settings_repository.dart';
import '../../../shopping/domain/repositories/shopping_settings_repository.dart';

part 'inventory_event.dart';
part 'inventory_state.dart';

/// Event transformer that debounces incoming events and cancels stale
/// in-flight handlers when a new event arrives (switchMap / restartable).
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) =>
      restartable<E>().call(events.debounce(duration), mapper);
}

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc(
    this._repository, {
    NotificationSyncService? notificationSyncService,
    ShoppingSettingsRepository? shoppingSettingsRepository,
  })  : _syncService = notificationSyncService,
        _settingsRepo = shoppingSettingsRepository ??
            SharedPreferencesShoppingSettingsRepository(),
        super(const InventoryState()) {
    on<InventoryStarted>(_onStarted);
    on<InventorySearchChanged>(
      _onSearchChanged,
      transformer: debounceRestartable(const Duration(milliseconds: 300)),
    );
    on<InventoryCategoryToggled>(_onCategoryToggled);
    on<InventoryExpiringFilterToggled>(_onExpiringFilterToggled);
    on<InventoryFiltersCleared>(_onFiltersCleared);
    on<InventoryItemAdded>(_onItemAdded);
    on<InventoryItemUpdated>(_onItemUpdated);
    on<InventoryItemDeleted>(_onItemDeleted);
    on<InventoryItemUsedUp>(_onItemUsedUp);
    on<InventoryItemWasted>(_onItemWasted);
    on<InventoryConsumeUndone>(_onConsumeUndone);
  }

  final PantryRepository _repository;
  final NotificationSyncService? _syncService;
  final ShoppingSettingsRepository _settingsRepo;

  Future<void> _onStarted(
    InventoryStarted event,
    Emitter<InventoryState> emit,
  ) async {
    await _refresh(emit);
    await _syncService?.syncNotifications();
  }

  Future<void> _onSearchChanged(
    InventorySearchChanged event,
    Emitter<InventoryState> emit,
  ) async {
    await _refresh(emit, searchQuery: event.query);
  }

  Future<void> _onCategoryToggled(
    InventoryCategoryToggled event,
    Emitter<InventoryState> emit,
  ) async {
    final updated = Set<String>.from(state.selectedCategories);
    if (updated.contains(event.category)) {
      updated.remove(event.category);
    } else {
      updated.add(event.category);
    }
    await _refresh(emit, selectedCategories: updated);
  }

  Future<void> _onExpiringFilterToggled(
    InventoryExpiringFilterToggled event,
    Emitter<InventoryState> emit,
  ) async {
    await _refresh(emit, expiringSoonOnly: !state.expiringSoonOnly);
  }

  Future<void> _onFiltersCleared(
    InventoryFiltersCleared event,
    Emitter<InventoryState> emit,
  ) async {
    await _refresh(
      emit,
      searchQuery: '',
      selectedCategories: const {},
      expiringSoonOnly: false,
    );
  }

  Future<void> _onItemAdded(
    InventoryItemAdded event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.add(event.item);
      await _refresh(emit);
      await _syncService?.syncNotifications();
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
      await _syncService?.syncNotifications();
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
      await _syncService?.syncNotifications();
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onItemUsedUp(
    InventoryItemUsedUp event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      final addToShopping = await _settingsRepo.getAddUsedUpToShoppingList();
      final result = await _repository.consume(
        item: event.item,
        reason: PantryEventReason.used,
        addToShoppingList: addToShopping,
      );
      emit(state.copyWith(lastConsumeResult: () => result));
      await _refresh(emit);
      await _syncService?.syncNotifications();
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onItemWasted(
    InventoryItemWasted event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      final result = await _repository.consume(
        item: event.item,
        reason: PantryEventReason.wasted,
        addToShoppingList: false,
      );
      emit(state.copyWith(lastConsumeResult: () => result));
      await _refresh(emit);
      await _syncService?.syncNotifications();
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onConsumeUndone(
    InventoryConsumeUndone event,
    Emitter<InventoryState> emit,
  ) async {
    try {
      await _repository.undoConsume(event.result);
      emit(state.copyWith(lastConsumeResult: () => null));
      await _refresh(emit);
      await _syncService?.syncNotifications();
    } catch (e) {
      emit(
        state.copyWith(
          status: InventoryStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _refresh(
    Emitter<InventoryState> emit, {
    String? searchQuery,
    Set<String>? selectedCategories,
    bool? expiringSoonOnly,
  }) async {
    final query = searchQuery ?? state.searchQuery;
    final categories = selectedCategories ?? state.selectedCategories;
    final expiringOnly = expiringSoonOnly ?? state.expiringSoonOnly;

    if (state.status == InventoryStatus.initial) {
      emit(state.copyWith(status: InventoryStatus.loading));
    }

    try {
      final total = await _repository.countAll();
      final items = await _repository.search(
        query: query.trim().isEmpty ? null : query.trim(),
        categories: categories.isEmpty ? null : categories,
        expiringWithinDays: expiringOnly ? 3 : null,
      );

      emit(
        state.copyWith(
          status: InventoryStatus.success,
          items: items,
          totalItemCount: total,
          searchQuery: query,
          selectedCategories: categories,
          expiringSoonOnly: expiringOnly,
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
