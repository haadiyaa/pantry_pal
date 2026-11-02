import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesOnboardingRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesOnboardingRepository();
  });

  group('SharedPreferencesOnboardingRepository', () {
    test('isOnboardingCompleted defaults to false', () async {
      expect(await repository.isOnboardingCompleted(), isFalse);
    });

    test('completeOnboarding sets flag to true', () async {
      await repository.completeOnboarding();
      expect(await repository.isOnboardingCompleted(), isTrue);
    });

    test('resetOnboarding clears flag back to false', () async {
      await repository.completeOnboarding();
      expect(await repository.isOnboardingCompleted(), isTrue);

      await repository.resetOnboarding();
      expect(await repository.isOnboardingCompleted(), isFalse);
    });
  });
}

