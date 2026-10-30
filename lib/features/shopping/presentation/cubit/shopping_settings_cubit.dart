import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/shopping_settings_repository.dart';

/// Cubit managing user preference for auto-adding used-up items to the shopping list.
class ShoppingSettingsCubit extends Cubit<bool> {
  ShoppingSettingsCubit(this._settingsRepo) : super(true) {
    loadSettings();
  }

  final ShoppingSettingsRepository _settingsRepo;

  Future<void> loadSettings() async {
    final enabled = await _settingsRepo.getAddUsedUpToShoppingList();
    if (!isClosed) {
      emit(enabled);
    }
  }

  Future<void> toggle(bool enabled) async {
    emit(enabled);
    await _settingsRepo.setAddUsedUpToShoppingList(enabled);
  }
}

