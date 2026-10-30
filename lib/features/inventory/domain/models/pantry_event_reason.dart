/// Reason an item was consumed or removed from the pantry.
enum PantryEventReason {
  used('used'),
  wasted('wasted'),
  deleted('deleted');

  const PantryEventReason(this.storageKey);

  final String storageKey;

  static PantryEventReason fromStorageKey(String key) {
    return PantryEventReason.values.firstWhere(
      (r) => r.storageKey == key,
      orElse: () => PantryEventReason.deleted,
    );
  }
}

