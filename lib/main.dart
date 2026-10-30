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
import 'features/product_lookup/data/datasources/open_food_facts_api.dart';
import 'features/product_lookup/data/repositories/cached_product_lookup_repository.dart';
import 'features/product_lookup/domain/repositories/product_lookup_repository.dart';
import 'features/product_lookup/presentation/bloc/product_lookup_bloc.dart';

import 'features/receipt/data/services/app_image_picker_service.dart';
import 'features/receipt/data/services/mlkit_text_recognizer.dart';
import 'features/receipt/domain/services/image_picker_service.dart';
import 'features/receipt/domain/services/receipt_parser.dart';
import 'features/receipt/domain/services/text_recognizer.dart';

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
  });

  final PantryRepository pantryRepository;
  final ProductLookupRepository productRepository;
  final NotificationSettingsRepository notificationSettingsRepository;
  final NotificationScheduler notificationScheduler;
  final NotificationSyncService notificationSyncService;

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
        RepositoryProvider<TextRecognizer>(
          create: (_) => MlKitTextRecognizer(),
        ),
        RepositoryProvider<ReceiptParser>(
          create: (_) => const ReceiptParser(),
        ),
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
        ],
        child: MaterialApp.router(
          title: 'Pantry Pal',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.green,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.green,
            brightness: Brightness.dark,
          ),
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
