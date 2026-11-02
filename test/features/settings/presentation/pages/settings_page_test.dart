import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/inventory/domain/repositories/pantry_repository.dart';
import 'package:pantry_pal/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:pantry_pal/features/settings/domain/services/user_data_service.dart';
import 'package:pantry_pal/features/settings/presentation/pages/settings_page.dart';
import 'package:pantry_pal/features/shopping/domain/repositories/shopping_settings_repository.dart';
import 'package:pantry_pal/features/shopping/presentation/cubit/shopping_settings_cubit.dart';

class MockUserDataService extends Mock implements UserDataService {}

class MockShoppingSettingsRepository extends Mock
    implements ShoppingSettingsRepository {}

class MockPantryRepository extends Mock implements PantryRepository {}

void main() {
  late MockUserDataService userDataService;
  late MockShoppingSettingsRepository shoppingSettingsRepo;
  late MockPantryRepository pantryRepo;

  setUp(() {
    userDataService = MockUserDataService();
    shoppingSettingsRepo = MockShoppingSettingsRepository();
    pantryRepo = MockPantryRepository();

    when(() => shoppingSettingsRepo.getAddUsedUpToShoppingList())
        .thenAnswer((_) async => true);
    when(() => shoppingSettingsRepo.setAddUsedUpToShoppingList(any()))
        .thenAnswer((_) async {});
    when(() => pantryRepo.countAll()).thenAnswer((_) async => 0);
    when(() => pantryRepo.search(
          query: any(named: 'query'),
          categories: any(named: 'categories'),
          expiringWithinDays: any(named: 'expiringWithinDays'),
        )).thenAnswer((_) async => []);
  });

  Widget createSubject() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<UserDataService>.value(value: userDataService),
        RepositoryProvider<ShoppingSettingsRepository>.value(
          value: shoppingSettingsRepo,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ShoppingSettingsCubit(shoppingSettingsRepo),
          ),
          BlocProvider(
            create: (_) => InventoryBloc(
              pantryRepo,
              shoppingSettingsRepository: shoppingSettingsRepo,
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );
  }

  testWidgets('SettingsPage renders sections and primary preference tiles',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Notifications & Reminders'), findsOneWidget);
    expect(find.text('Shopping List Auto-Add'), findsOneWidget);
    expect(find.text('Data & Privacy'), findsOneWidget);
    expect(find.text('Export Data as JSON'), findsOneWidget);
    expect(find.text('Clear All Data'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Open Source Licenses'), findsOneWidget);
  });

  testWidgets('SettingsPage opens Privacy Policy dialog on tap',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('100% Local-First & Private'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('100% Local-First & Private'), findsNothing);
  });

  testWidgets('SettingsPage double confirmation triggers clearAllData',
      (tester) async {
    when(() => userDataService.clearAllData()).thenAnswer((_) async {});

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Tap Clear All Data
    await tester.tap(find.text('Clear All Data'));
    await tester.pumpAndSettle();

    // First dialog
    expect(find.text('Clear All Data?'), findsOneWidget);
    await tester.tap(find.text('Delete Everything'));
    await tester.pumpAndSettle();

    // Second dialog
    expect(find.text('Are you completely sure?'), findsOneWidget);
    await tester.tap(find.text('Confirm & Wipe'));
    await tester.pumpAndSettle();

    verify(() => userDataService.clearAllData()).called(1);
    expect(find.text('All data cleared successfully.'), findsOneWidget);
  });
}
