import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pantry_pal/core/database/app_database.dart';
import 'package:pantry_pal/features/inventory/data/repositories/sqlite_pantry_repository.dart';
import 'package:pantry_pal/features/notifications/data/repositories/shared_preferences_notification_settings_repository.dart';
import 'package:pantry_pal/features/notifications/data/services/app_notification_sync_service.dart';
import 'package:pantry_pal/features/notifications/data/services/local_notification_scheduler.dart';
import 'package:pantry_pal/features/product_lookup/data/datasources/open_food_facts_api.dart';
import 'package:pantry_pal/features/product_lookup/data/repositories/cached_product_lookup_repository.dart';
import 'package:pantry_pal/features/recipes/data/datasources/themealdb_remote_datasource.dart';
import 'package:pantry_pal/features/recipes/data/repositories/cached_recipe_repository.dart';
import 'package:pantry_pal/features/shopping/data/repositories/shared_preferences_shopping_settings_repository.dart';
import 'package:pantry_pal/features/shopping/data/repositories/sqlite_shopping_repository.dart';
import 'package:pantry_pal/features/stats/data/repositories/shared_preferences_stats_period_repository.dart';
import 'package:pantry_pal/features/stats/data/repositories/sqlite_stats_repository.dart';
import 'package:pantry_pal/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'Core Journey: Add item -> See in pantry -> Mark used up -> See on shopping list',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'auto_add_used_up_to_shopping': true,
      });
      // 1. Initialize clean SQLite and isolated services
      final appDb = AppDatabase(
        databaseFactory: databaseFactoryFfi,
        dbPath: inMemoryDatabasePath,
      );
      final pantryRepo = SqlitePantryRepository(appDb);
      final productRepo = CachedProductLookupRepository(
        appDb: appDb,
        api: OpenFoodFactsApi(),
      );
      final scheduler = LocalNotificationScheduler();
      final settingsRepo = SharedPreferencesNotificationSettingsRepository();
      final syncService = AppNotificationSyncService(
        pantryRepository: pantryRepo,
        settingsRepository: settingsRepo,
        scheduler: scheduler,
      );
      final recipeRemoteDataSource = TheMealDbRemoteDataSource();
      final recipeRepo = CachedRecipeRepository(
        appDb: appDb,
        remoteDataSource: recipeRemoteDataSource,
      );
      final shoppingRepo = SqliteShoppingRepository(appDb);
      final shoppingSettingsRepo =
          SharedPreferencesShoppingSettingsRepository();
      await shoppingSettingsRepo.setAddUsedUpToShoppingList(true);

      final statsRepo = SqliteStatsRepository(appDb);
      final statsPeriodRepo = SharedPreferencesStatsPeriodRepository();

      await tester.pumpWidget(
        PantryPalApp(
          pantryRepository: pantryRepo,
          productRepository: productRepo,
          notificationSettingsRepository: settingsRepo,
          notificationScheduler: scheduler,
          notificationSyncService: syncService,
          recipeRepository: recipeRepo,
          shoppingRepository: shoppingRepo,
          shoppingSettingsRepository: shoppingSettingsRepo,
          statsRepository: statsRepo,
          statsPeriodRepository: statsPeriodRepo,
        ),
      );
      await tester.pumpAndSettle();

      // 2. Add an item: tap add FAB
      final fab = find.byKey(const Key('add_item_fab'));
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Fill in item name
      final nameField = find.byKey(const Key('item_name_field'));
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Almond Milk');

      // Tap Save
      final saveBtn = find.byKey(const Key('save_item_button'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // 3. Confirm item is present in pantry list
      expect(find.text('Almond Milk'), findsOneWidget);

      // 4. Mark item as "Used up" by swiping start-to-end
      await tester.fling(find.text('Almond Milk'), const Offset(600, 0), 1000);
      await tester.pumpAndSettle();

      // Confirm pantry is now empty
      expect(find.text('Your pantry is empty'), findsOneWidget);

      // 5. Navigate to Shopping List screen via AppBar action
      final shoppingNavBtn = find.byKey(const Key('shopping_list_button'));
      expect(shoppingNavBtn, findsOneWidget);
      await tester.tap(shoppingNavBtn);
      await tester.pumpAndSettle();

      // 6. Verify item was automatically added to shopping list with "Used up" source
      expect(find.text('Almond Milk'), findsOneWidget);
      expect(find.textContaining('Used up'), findsOneWidget);

      await appDb.close();
    },
  );
}
