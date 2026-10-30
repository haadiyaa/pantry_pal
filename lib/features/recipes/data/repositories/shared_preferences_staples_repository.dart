import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/staples_repository.dart';

/// SharedPreferences implementation of [StaplesRepository].
class SharedPreferencesStaplesRepository implements StaplesRepository {
  SharedPreferencesStaplesRepository({this.preferences});

  final SharedPreferences? preferences;
  static const String _key = 'unavailable_staples_override';

  Future<SharedPreferences> get _prefs async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<Set<String>> getUnavailableStaples() async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_key) ?? const [];
    return list.toSet();
  }

  @override
  Future<void> setStapleAvailability(String stapleKeyword, bool isAvailable) async {
    final prefs = await _prefs;
    final set = (prefs.getStringList(_key) ?? []).toSet();
    final normalized = stapleKeyword.trim().toLowerCase();

    if (isAvailable) {
      set.remove(normalized);
    } else {
      set.add(normalized);
    }

    await prefs.setStringList(_key, set.toList());
  }
}
