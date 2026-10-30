import '../../../inventory/domain/models/pantry_item.dart';
import '../models/shopping_item.dart';

/// Repository interface for shopping list storage operations.
abstract class ShoppingRepository {
  /// Loads all shopping items sorted by status and category.
  Future<List<ShoppingItem>> getAll();

  /// Emits updated list whenever shopping items change.
  Stream<List<ShoppingItem>> watchAll();

  /// Retrieves an item by its ID.
  Future<ShoppingItem?> getById(int id);

  /// Adds an item. If an unchecked item with the same normalized name
  /// already exists, merges by incrementing quantity and combining source labels.
  Future<int> add(ShoppingItem item);

  /// Batch adds a list of shopping items, merging duplicates.
  Future<void> addAll(List<ShoppingItem> items);

  /// Updates an existing shopping item.
  Future<void> update(ShoppingItem item);

  /// Deletes a shopping item by ID.
  Future<void> delete(int id);

  /// Restores a previously deleted item with its original ID (for undo).
  Future<void> restore(ShoppingItem item);

  /// Toggles or sets the bought state for an item.
  Future<void> setBought(int id, bool isBought, {DateTime? boughtAt});

  /// Deletes all items marked as bought. Returns the deleted items for undo.
  Future<List<ShoppingItem>> clearBought();

  /// Atomically inserts reviewed [pantryItems] into the pantry and deletes
  /// the corresponding [shoppingItemIdsToRemove] in a single transaction.
  Future<void> moveBoughtToPantry(
    List<PantryItem> pantryItems,
    List<int> shoppingItemIdsToRemove,
  );
}

