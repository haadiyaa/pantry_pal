import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/settings/domain/services/user_data_service.dart';
import 'package:pantry_pal/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:pantry_pal/features/settings/presentation/cubit/settings_state.dart';

class MockUserDataService extends Mock implements UserDataService {}

void main() {
  late MockUserDataService service;

  setUp(() {
    service = MockUserDataService();
  });

  group('SettingsCubit', () {
    test('initial state has default flags', () {
      final cubit = SettingsCubit(userDataService: service);
      expect(cubit.state, const SettingsState());
      cubit.close();
    });

    blocTest<SettingsCubit, SettingsState>(
      'clearAllData calls service and emits clearSuccess',
      build: () {
        when(() => service.clearAllData()).thenAnswer((_) async {});
        return SettingsCubit(userDataService: service);
      },
      act: (cubit) => cubit.clearAllData(),
      expect: () => [
        const SettingsState(isClearing: true),
        const SettingsState(isClearing: false, clearSuccess: true),
      ],
      verify: (_) {
        verify(() => service.clearAllData()).called(1);
      },
    );

    blocTest<SettingsCubit, SettingsState>(
      'clearAllData emits error on failure',
      build: () {
        when(() => service.clearAllData())
            .thenThrow(Exception('Database locked'));
        return SettingsCubit(userDataService: service);
      },
      act: (cubit) => cubit.clearAllData(),
      expect: () => [
        const SettingsState(isClearing: true),
        const SettingsState(
          isClearing: false,
          errorMessage: 'Failed to delete data: Exception: Database locked',
        ),
      ],
    );
  });
}

