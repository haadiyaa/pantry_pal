import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../../notifications/domain/services/notification_sync_service.dart';
import '../../../receipt/domain/services/expiry_suggester.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';
import 'shopping_batch_review_item.dart';
import 'shopping_batch_review_state.dart';

class ShoppingBatchReviewCubit extends Cubit<ShoppingBatchReviewState> {
  ShoppingBatchReviewCubit({
    required this.shoppingRepository,
    required this.pantryRepository,
    this.notificationSyncService,
    List<ShoppingItem>? boughtItems,
    ExpirySuggester? expirySuggester,
    DateTime Function()? nowProvider,
  })  : _expirySuggester = expirySuggester ?? const ExpirySuggester(),
        _nowProvider = nowProvider ?? DateTime.now,
        super(const ShoppingBatchReviewState()) {
    if (boughtItems != null) {
      _initialize(boughtItems);
    } else {
      _loadBought();
    }
  }

  final ShoppingRepository shoppingRepository;
  final PantryRepository pantryRepository;
  final NotificationSyncService? notificationSyncService;
  final ExpirySuggester _expirySuggester;
  final DateTime Function() _nowProvider;

  Future<void> _loadBought() async {
    try {
      final all = await shoppingRepository.getAll();
      final bought = all.where((i) => i.isBought).toList();
      _initialize(bought);
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingBatchReviewStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void _initialize(List<ShoppingItem> boughtItems) {
    final now = _nowProvider();
    final reviewItems = boughtItems.map((item) {
      final category = item.category.isNotEmpty ? item.category : 'Other';
      final suggestedExpiry = _expirySuggester.suggestExpiryDate(
        category: category,
        baseDate: now,
      );

      return ShoppingBatchReviewItem(
        shoppingItemId: item.id ?? 0,
        name: item.name,
        quantity: item.quantity,
        category: category,
        expiryDate: suggestedExpiry,
        isIncluded: true,
        isEstimated: true,
      );
    }).toList();

    emit(
      state.copyWith(
        status: ShoppingBatchReviewStatus.initial,
        items: reviewItems,
      ),
    );
  }

  void nameChanged(int shoppingItemId, String name) {
    final updated = state.items.map((item) {
      if (item.shoppingItemId == shoppingItemId) {
        return item.copyWith(name: name);
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updated));
  }

  void quantityChanged(int shoppingItemId, int quantity) {
    if (quantity < 1) return;
    final updated = state.items.map((item) {
      if (item.shoppingItemId == shoppingItemId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updated));
  }

  void categoryChanged(int shoppingItemId, String category) {
    final now = _nowProvider();
    final updated = state.items.map((item) {
      if (item.shoppingItemId == shoppingItemId) {
        // Recalculate estimated expiry date if user hasn't manually picked one
        final newExpiry = item.isEstimated
            ? _expirySuggester.suggestExpiryDate(
                category: category,
                baseDate: now,
              )
            : item.expiryDate;
        return item.copyWith(
          category: category,
          expiryDate: newExpiry,
        );
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updated));
  }

  void expiryDateChanged(int shoppingItemId, DateTime date) {
    final updated = state.items.map((item) {
      if (item.shoppingItemId == shoppingItemId) {
        return item.copyWith(
          expiryDate: date,
          isEstimated: false,
        );
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updated));
  }

  void toggleIncluded(int shoppingItemId) {
    final updated = state.items.map((item) {
      if (item.shoppingItemId == shoppingItemId) {
        return item.copyWith(isIncluded: !item.isIncluded);
      }
      return item;
    }).toList();
    emit(state.copyWith(items: updated));
  }

  Future<void> saveToPantry() async {
    final toSave = state.includedItems;
    if (toSave.isEmpty) return;

    emit(state.copyWith(status: ShoppingBatchReviewStatus.submitting));

    try {
      final now = _nowProvider();
      final pantryItems = <PantryItem>[];
      final shoppingIds = <int>[];

      for (final item in toSave) {
        pantryItems.add(
          PantryItem(
            name: item.name.trim(),
            quantity: item.quantity,
            category: item.category,
            expiryDate: item.expiryDate,
            addedAt: now,
          ),
        );
        shoppingIds.add(item.shoppingItemId);
      }

      await shoppingRepository.moveBoughtToPantry(pantryItems, shoppingIds);
      await notificationSyncService?.syncNotifications();

      emit(state.copyWith(status: ShoppingBatchReviewStatus.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: ShoppingBatchReviewStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }
}
