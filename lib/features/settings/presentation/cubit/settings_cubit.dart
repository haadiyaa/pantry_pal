import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/user_data_service.dart';
import 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this.userDataService,
  }) : super(const SettingsState());

  final UserDataService userDataService;

  Future<void> exportData() async {
    emit(state.copyWith(isExporting: true, errorMessage: () => null));
    try {
      final jsonString = await userDataService.exportDataAsJson();
      await SharePlus.instance.share(
        ShareParams(
          text: jsonString,
          subject:
              'Pantry Pal Data Backup (${DateTime.now().toIso8601String().substring(0, 10)})',
        ),
      );
      emit(state.copyWith(isExporting: false));
    } catch (e) {
      emit(
        state.copyWith(
          isExporting: false,
          errorMessage: () => 'Failed to export data: $e',
        ),
      );
    }
  }

  Future<void> clearAllData() async {
    emit(state.copyWith(isClearing: true, errorMessage: () => null));
    try {
      await userDataService.clearAllData();
      emit(state.copyWith(isClearing: false, clearSuccess: true));
    } catch (e) {
      emit(
        state.copyWith(
          isClearing: false,
          errorMessage: () => 'Failed to delete data: $e',
        ),
      );
    }
  }
}
