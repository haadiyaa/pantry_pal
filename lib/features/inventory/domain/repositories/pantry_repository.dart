import '../models/pantry_item.dart';

/// Abstract repository defining pantry operations.
/// All Blocs depend exclusively on this interface for clean testability.
abstract class PantryRepository {
  Future<List<PantryItem>> getAll();
  Future<PantryItem?> getById(int id);
  Future<List<PantryItem>> getExpiringWithin(int days);
  Future<List<PantryItem>> search({
    String? query,
    Set<String>? categories,
    int? expiringWithinDays,
  });
  Future<int> countAll();
  Future<int> add(PantryItem item);
  Future<void> update(PantryItem item);
  Future<void> delete(int id);
}
