import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/recipes/data/repositories/shared_preferences_staples_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesStaplesRepository', () {
    test('returns empty set by default (all staples assumed available)',
        () async {
      final repo = SharedPreferencesStaplesRepository();
      final unavailable = await repo.getUnavailableStaples();
      expect(unavailable, isEmpty);
    });

    test('marks staple as unavailable and persists in SharedPreferences',
        () async {
      final repo = SharedPreferencesStaplesRepository();

      await repo.setStapleAvailability('Cooking Oil', false);
      final set1 = await repo.getUnavailableStaples();
      expect(set1, contains('cooking oil'));

      // Case and whitespace normalized
      await repo.setStapleAvailability('  SALT  ', false);
      final set2 = await repo.getUnavailableStaples();
      expect(set2, contains('salt'));
      expect(set2.length, 2);
    });

    test('restores staple availability when set to true', () async {
      final repo = SharedPreferencesStaplesRepository();

      await repo.setStapleAvailability('oil', false);
      expect(await repo.getUnavailableStaples(), contains('oil'));

      await repo.setStapleAvailability('oil', true);
      expect(await repo.getUnavailableStaples(), isEmpty);
    });
  });
}

