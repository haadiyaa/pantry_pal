import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'features/inventory/data/repositories/sqlite_pantry_repository.dart';
import 'features/inventory/domain/repositories/pantry_repository.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/notifications/data/repositories/shared_preferences_notification_settings_repository.dart';
import 'features/notifications/data/services/app_notification_sync_service.dart';
import 'features/notifications/data/services/local_notification_scheduler.dart';
import 'features/notifications/domain/repositories/notification_settings_repository.dart';
import 'features/notifications/domain/services/notification_scheduler.dart';
import 'features/notifications/domain/services/notification_sync_service.dart';
import 'features/notifications/presentation/cubit/notification_settings_cubit.dart';
import 'features/onboarding/data/repositories/shared_preferences_onboarding_repository.dart';
import 'features/onboarding/domain/repositories/onboarding_repository.dart';
import 'features/product_lookup/data/datasources/open_food_facts_api.dart';
import 'features/product_lookup/data/repositories/cached_product_lookup_repository.dart';
import 'features/product_lookup/domain/repositories/product_lookup_repository.dart';
import 'features/product_lookup/presentation/bloc/product_lookup_bloc.dart';

import 'features/receipt/data/services/app_image_picker_service.dart';
import 'features/receipt/data/services/mlkit_text_recognizer.dart';
import 'features/receipt/domain/services/image_picker_service.dart';
import 'features/receipt/domain/services/receipt_parser.dart';
import 'features/receipt/domain/services/text_recognizer.dart';

import 'features/recipes/data/datasources/themealdb_remote_datasource.dart';
import 'features/recipes/data/repositories/cached_recipe_repository.dart';
import 'features/recipes/data/repositories/shared_preferences_staples_repository.dart';
import 'features/recipes/domain/repositories/recipe_repository.dart';
import 'features/recipes/domain/repositories/staples_repository.dart';

import 'features/settings/data/services/sqlite_user_data_service.dart';
import 'features/settings/domain/services/user_data_service.dart';

import 'features/shopping/data/repositories/shared_preferences_shopping_settings_repository.dart';
import 'features/shopping/data/repositories/sqlite_shopping_repository.dart';
import 'features/shopping/domain/repositories/shopping_repository.dart';
import 'features/shopping/domain/repositories/shopping_settings_repository.dart';
import 'features/shopping/presentation/cubit/shopping_badge_cubit.dart';
import 'features/shopping/presentation/cubit/shopping_settings_cubit.dart';

import 'features/stats/data/repositories/shared_preferences_stats_period_repository.dart';
import 'features/stats/data/repositories/sqlite_stats_repository.dart';
import 'features/stats/domain/repositories/stats_period_repository.dart';
import 'features/stats/domain/repositories/stats_repository.dart';
import 'features/stats/presentation/cubit/stats_cubit.dart';

void _handleNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return;

  if (payload.startsWith('item:')) {
    final itemId = payload.substring('item:'.length);
    appRouter.push('/item/$itemId');
  } else if (payload.startsWith('digest:')) {
    appRouter.go('/?filter=expiring');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Error Boundary (no 3rd-party tracking; local log + graceful release fallback)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[PlatformDispatcher] Unhandled error: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    return _GlobalErrorFallback(details: details);
  };

  // 1. Initialize timezone support
  tz.initializeTimeZones();
  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
  } catch (e) {
    debugPrint('Failed to load device timezone, falling back to UTC: $e');
  }

  // 2. Initialize database and core repositories
  final appDb = AppDatabase.instance;
  final pantryRepo = SqlitePantryRepository(appDb);
  final productRepo = CachedProductLookupRepository(
    appDb: appDb,
    api: OpenFoodFactsApi(),
  );

  // 3. Initialize notifications infrastructure
  final scheduler = LocalNotificationScheduler();
  await scheduler.init(
    onNotificationTap: (payload) {
      _handleNotificationPayload(payload);
    },
  );

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
  unawaited(
    recipeRepo.cleanOldCache().catchError((Object e) {
      debugPrint('Failed to clean old recipe cache: $e');
    }),
  );

  final shoppingRepo = SqliteShoppingRepository(appDb);
  final shoppingSettingsRepo = SharedPreferencesShoppingSettingsRepository();
  final statsRepo = SqliteStatsRepository(appDb);
  final statsPeriodRepo = SharedPreferencesStatsPeriodRepository();
  final onboardingRepo = SharedPreferencesOnboardingRepository();
  final isOnboardingCompleted = await onboardingRepo.isOnboardingCompleted();
  final userDataService = SqliteUserDataService(appDb);

  // 4. Handle cold-launch from notification tap
  final coldLaunchPayload = await scheduler.getLaunchPayload();
  if (coldLaunchPayload != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationPayload(coldLaunchPayload);
    });
  }

  runApp(
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
      onboardingRepository: onboardingRepo,
      userDataService: userDataService,
      initialLocation: isOnboardingCompleted ? '/' : '/onboarding',
    ),
  );
}

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({
    super.key,
    required this.pantryRepository,
    required this.productRepository,
    required this.notificationSettingsRepository,
    required this.notificationScheduler,
    required this.notificationSyncService,
    required this.recipeRepository,
    required this.shoppingRepository,
    required this.shoppingSettingsRepository,
    required this.statsRepository,
    required this.statsPeriodRepository,
    this.onboardingRepository,
    this.userDataService,
    this.initialLocation = '/',
  });

  final PantryRepository pantryRepository;
  final ProductLookupRepository productRepository;
  final NotificationSettingsRepository notificationSettingsRepository;
  final NotificationScheduler notificationScheduler;
  final NotificationSyncService notificationSyncService;
  final RecipeRepository recipeRepository;
  final ShoppingRepository shoppingRepository;
  final ShoppingSettingsRepository shoppingSettingsRepository;
  final StatsRepository statsRepository;
  final StatsPeriodRepository statsPeriodRepository;
  final OnboardingRepository? onboardingRepository;
  final UserDataService? userDataService;
  final String initialLocation;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PantryRepository>.value(value: pantryRepository),
        RepositoryProvider<ProductLookupRepository>.value(
          value: productRepository,
        ),
        RepositoryProvider<NotificationSettingsRepository>.value(
          value: notificationSettingsRepository,
        ),
        RepositoryProvider<NotificationScheduler>.value(
          value: notificationScheduler,
        ),
        RepositoryProvider<NotificationSyncService>.value(
          value: notificationSyncService,
        ),
        RepositoryProvider<RecipeRepository>.value(value: recipeRepository),
        RepositoryProvider<ShoppingRepository>.value(value: shoppingRepository),
        RepositoryProvider<ShoppingSettingsRepository>.value(
          value: shoppingSettingsRepository,
        ),
        RepositoryProvider<StatsRepository>.value(value: statsRepository),
        RepositoryProvider<StatsPeriodRepository>.value(
          value: statsPeriodRepository,
        ),
        RepositoryProvider<OnboardingRepository>(
          create: (_) =>
              onboardingRepository ?? SharedPreferencesOnboardingRepository(),
        ),
        RepositoryProvider<UserDataService>(
          create: (_) =>
              userDataService ?? SqliteUserDataService(AppDatabase.instance),
        ),
        RepositoryProvider<StaplesRepository>(
          create: (_) => SharedPreferencesStaplesRepository(),
        ),
        RepositoryProvider<TextRecognizer>(
          create: (_) => MlKitTextRecognizer(),
        ),
        RepositoryProvider<ReceiptParser>(create: (_) => const ReceiptParser()),
        RepositoryProvider<ImagePickerService>(
          create: (_) => AppImagePickerService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => InventoryBloc(
              pantryRepository,
              notificationSyncService: notificationSyncService,
              shoppingSettingsRepository: shoppingSettingsRepository,
            )..add(const InventoryStarted()),
          ),
          BlocProvider(
            create: (_) => ProductLookupBloc(
              productRepository: productRepository,
              pantryRepository: pantryRepository,
            ),
          ),
          BlocProvider(
            create: (_) => NotificationSettingsCubit(
              settingsRepository: notificationSettingsRepository,
              scheduler: notificationScheduler,
              syncService: notificationSyncService,
            )..loadSettings(),
          ),
          BlocProvider(create: (_) => ShoppingBadgeCubit(shoppingRepository)),
          BlocProvider(
            create: (_) => ShoppingSettingsCubit(shoppingSettingsRepository),
          ),
          BlocProvider(
            create: (_) => StatsCubit(
              statsRepository: statsRepository,
              periodRepository: statsPeriodRepository,
            )..init(),
          ),
        ],
        child: MaterialApp.router(
          title: 'Pantry Pal',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.green,
            brightness: Brightness.dark,
          ),
          routerConfig: createAppRouter(initialLocation: initialLocation),
        ),
      ),
    );
  }
}

class _GlobalErrorFallback extends StatelessWidget {
  const _GlobalErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'An unexpected error occurred. You can return to your pantry safely.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      if (appRouter.canPop()) {
                        appRouter.pop();
                      } else {
                        appRouter.go('/');
                      }
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Return to Pantry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
