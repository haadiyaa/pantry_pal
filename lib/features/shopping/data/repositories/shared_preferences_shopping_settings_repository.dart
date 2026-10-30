import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/shopping_settings_repository.dart';

class SharedPreferencesShoppingSettingsRepository
    implements ShoppingSettingsRepository {
  SharedPreferencesShoppingSettingsRepository({this.preferences});

  final SharedPreferences? preferences;
  static const _keyAddUsedUp = 'setting_add_used_up_to_shopping_list';

  Future<SharedPreferences> get _prefs async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<bool> getAddUsedUpToShoppingList() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyAddUsedUp) ?? true;
  }

  @override
  Future<void> setAddUsedUpToShoppingList(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyAddUsedUp, enabled);
  }
}

