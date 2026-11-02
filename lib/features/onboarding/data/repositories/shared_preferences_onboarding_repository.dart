import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/onboarding_repository.dart';

/// Implementation of [OnboardingRepository] backed by [SharedPreferences].
class SharedPreferencesOnboardingRepository implements OnboardingRepository {
  SharedPreferencesOnboardingRepository({SharedPreferences? preferences})
      : _prefs = preferences;

  SharedPreferences? _prefs;

  static const _keyCompleted = 'onboarding_completed_flag';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> isOnboardingCompleted() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  @override
  Future<void> completeOnboarding() async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyCompleted, true);
  }

  @override
  Future<void> resetOnboarding() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyCompleted);
  }
}

