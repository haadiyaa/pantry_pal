import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../../notifications/domain/services/notification_sync_service.dart';
import '../../domain/models/receipt_draft.dart';
import 'receipt_review_item.dart';
import 'receipt_review_state.dart';

/// Manages the verification, user adjustments, duplicate resolution, and atomic batch save
/// of scanned receipt items into the pantry database.
class ReceiptReviewCubit extends Cubit<ReceiptReviewState> {
  ReceiptReviewCubit({
    required this.pantryRepository,
    this.notificationSyncService,
  }) : super(const ReceiptReviewState());

  final PantryRepository pantryRepository;
  final NotificationSyncService? notificationSyncService;

  Future<void> initialize(ReceiptDraft draft) async {
    emit(state.copyWith(status: ReceiptReviewStatus.loading));

    try {
      final existingItems = await pantryRepository.getAll();
      final reviewItems = <ReceiptReviewItem>[];

      for (var i = 0; i < draft.items.length; i++) {
        final draftItem = draft.items[i];
        final normalizedDraftName = draftItem.name.toLowerCase().trim();

        // Check for duplicates in existing pantry
        PantryItem? match;
        for (final existing in existingItems) {
          if (existing.name.toLowerCase().trim() == normalizedDraftName) {
            match = existing;
            break;
          }
        }

        reviewItems.add(
          ReceiptReviewItem(
            id: 'item_$i',
            name: draftItem.name,
            quantity: draftItem.quantity,
            priceInPaise: draftItem.priceInPaise,
            category: draftItem.category,
            confidence: draftItem.confidence,
            isIncluded: draftItem.isIncluded,
            expiryDate: draftItem.suggestedExpiryDate ??
                DateTime.now().add(const Duration(days: 7)),
            existingItemId: match?.id,
            existingItemQuantity: match?.quantity,
            duplicateResolution: DuplicateResolution.addAsNew,
          ),
        );
      }

      // Sort so low-confidence items appear first to prompt user verification
      reviewItems.sort((a, b) {
        if (a.isLowConfidence && !b.isLowConfidence) return -1;
        if (!a.isLowConfidence && b.isLowConfidence) return 1;
        return 0;
      });

      emit(state.copyWith(
        status: ReceiptReviewStatus.ready,
        items: reviewItems,
        receiptDate: () => draft.receiptDate,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ReceiptReviewStatus.failure,
        errorMessage: () => 'Failed to initialize review items: $e',
      ));
    }
  }

  void toggleInclude(String id) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(isIncluded: !item.isIncluded);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  void selectAll(bool include) {
    final updated = state.items.map((item) {
      return item.copyWith(isIncluded: include);
    }).toList();

    emit(state.copyWith(items: updated));
  }

  void updateName(String id, String name) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(name: name);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  void updateQuantity(String id, int quantity) {
    if (quantity < 1) return;
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  void updateCategory(String id, String category) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(category: category);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  void updateExpiryDate(String id, DateTime date) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(expiryDate: date);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  void updatePrice(String id, int? priceInPaise) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(priceInPaise: () => priceInPaise);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  void deleteItem(String id) {
    final updated = state.items.where((item) => item.id != id).toList();
    emit(state.copyWith(items: updated));
  }

  void addItem() {
    final newId = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    final newItem = ReceiptReviewItem(
      id: newId,
      name: '',
      quantity: 1,
      category: 'Other',
      expiryDate: DateTime.now().add(const Duration(days: 7)),
      isIncluded: true,
    );

    emit(state.copyWith(items: [...state.items, newItem]));
  }

  void setDuplicateResolution(String id, DuplicateResolution resolution) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(duplicateResolution: resolution);
      }
      return item;
    }).toList();

    emit(state.copyWith(items: updated));
  }

  Future<void> saveAll() async {
    final includedItems = state.items.where((i) => i.isIncluded).toList();
    if (includedItems.isEmpty) return;

    // Validate names
    for (final item in includedItems) {
      if (item.name.trim().isEmpty) {
        emit(state.copyWith(
          errorMessage: () => 'Please enter a name for all included items.',
        ));
        return;
      }
    }

    emit(state.copyWith(
      status: ReceiptReviewStatus.saving,
      errorMessage: () => null,
    ));

    try {
      final itemsToInsert = <PantryItem>[];

      for (final item in includedItems) {
        if (item.isDuplicate &&
            item.duplicateResolution == DuplicateResolution.incrementExisting &&
            item.existingItemId != null) {
          // Fetch and update existing item quantity
          final existing = await pantryRepository.getById(item.existingItemId!);
          if (existing != null) {
            final updated = existing.copyWith(
              quantity: existing.quantity + item.quantity,
              // Update price if available
              priceInPaise: item.priceInPaise ?? existing.priceInPaise,
            );
            await pantryRepository.update(updated);
            continue;
          }
        }

        // Add as a new entry
        itemsToInsert.add(item.toPantryItem());
      }

      if (itemsToInsert.isNotEmpty) {
        // Atomic batch save inside a single SQLite transaction
        await pantryRepository.addAll(itemsToInsert);
      }

      // Rebuild the notification plan to account for newly saved items
      if (notificationSyncService != null) {
        await notificationSyncService!.syncNotifications();
      }

      emit(state.copyWith(
        status: ReceiptReviewStatus.saveSuccess,
        savedCount: includedItems.length,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ReceiptReviewStatus.failure,
        errorMessage: () => 'Failed to save items to pantry: $e',
      ));
    }
  }
}

