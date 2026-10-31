import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/stats_period.dart';
import '../../domain/repositories/stats_period_repository.dart';

/// SharedPreferences implementation of [StatsPeriodRepository].
class SharedPreferencesStatsPeriodRepository implements StatsPeriodRepository {
  SharedPreferencesStatsPeriodRepository({this.preferences});

  final SharedPreferences? preferences;
  static const String _key = 'stats_selected_period';

  Future<SharedPreferences> get _prefs async =>
      preferences ?? await SharedPreferences.getInstance();

  @override
  Future<StatsPeriod> getSelectedPeriod() async {
    final prefs = await _prefs;
    final value = prefs.getString(_key);
    if (value == null) return StatsPeriod.last30Days;
    return StatsPeriod.values.firstWhere(
      (p) => p.name == value,
      orElse: () => StatsPeriod.last30Days,
    );
  }

  @override
  Future<void> setSelectedPeriod(StatsPeriod period) async {
    final prefs = await _prefs;
    await prefs.setString(_key, period.name);
  }
}

