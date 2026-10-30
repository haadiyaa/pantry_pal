import '../models/consume_result.dart';
import '../models/pantry_event_reason.dart';
import '../models/pantry_item.dart';

/// Abstract repository defining pantry operations.
/// All Blocs depend exclusively on this interface for clean testability.
abstract class PantryRepository {
  Future<List<PantryItem>> getAll();
  Future<PantryItem?> getById(int id);
  Future<PantryItem?> getByBarcode(String barcode);
  Future<List<PantryItem>> getExpiringWithin(int days);
  Future<List<PantryItem>> search({
    String? query,
    Set<String>? categories,
    int? expiringWithinDays,
  });
  Future<int> countAll();
  Future<int> add(PantryItem item);
  Future<void> addAll(List<PantryItem> items);
  Future<void> update(PantryItem item);
  Future<void> delete(int id);

  /// Atomically consumes or removes [item], writes an audit event to pantry_events,
  /// and (only for reason `used` when [addToShoppingList] is true and quantity reached 0)
  /// adds or merges the row into the shopping list.
  Future<ConsumeResult> consume({
    required PantryItem item,
    required PantryEventReason reason,
    bool addToShoppingList = false,
    DateTime? occurredAt,
  });

  /// Atomically reverses a prior [consume] operation across all touched tables.
  Future<void> undoConsume(ConsumeResult result);
}
