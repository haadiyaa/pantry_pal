import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/features/shopping/data/repositories/shared_preferences_shopping_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesShoppingSettingsRepository', () {
    test('defaults to true (auto-add to shopping list on used up)', () async {
      final repo = SharedPreferencesShoppingSettingsRepository();
      expect(await repo.getAddUsedUpToShoppingList(), isTrue);
    });

    test('persists user setting when changed to false and true', () async {
      final repo = SharedPreferencesShoppingSettingsRepository();

      await repo.setAddUsedUpToShoppingList(false);
      expect(await repo.getAddUsedUpToShoppingList(), isFalse);

      await repo.setAddUsedUpToShoppingList(true);
      expect(await repo.getAddUsedUpToShoppingList(), isTrue);
    });
  });
}

