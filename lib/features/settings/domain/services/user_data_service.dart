/// Contract for managing user data export and deletion across local storage.
abstract interface class UserDataService {
  /// Exports all user pantry items, shopping items, and pantry events as formatted JSON.
  Future<String> exportDataAsJson();

  /// Permanently deletes all user pantry items, shopping items, events, and caches.
  Future<void> clearAllData();
}

