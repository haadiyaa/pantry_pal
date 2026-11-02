/// Contract for tracking whether the user has completed or skipped the first-run onboarding.
abstract interface class OnboardingRepository {
  /// Returns `true` if the user has already completed or skipped the onboarding flow.
  Future<bool> isOnboardingCompleted();

  /// Persists the flag marking onboarding as completed.
  Future<void> completeOnboarding();

  /// Resets the onboarding flag (used for testing or resetting user data).
  Future<void> resetOnboarding();
}

