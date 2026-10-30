/// Interface for persisting user overrides for kitchen staples.
///
/// Staples (salt, oil, water, etc.) start as assumed available. If a user
/// marks a staple as unavailable (e.g., they ran out of cooking oil), that
/// choice is remembered globally across all recipes.
abstract class StaplesRepository {
  /// Retrieves the set of normalized staple keywords marked as unavailable.
  Future<Set<String>> getUnavailableStaples();

  /// Updates availability for [stapleKeyword].
  Future<void> setStapleAvailability(String stapleKeyword, bool isAvailable);
}

