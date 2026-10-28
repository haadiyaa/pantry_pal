import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'features/inventory/data/repositories/sqlite_pantry_repository.dart';
import 'features/inventory/domain/repositories/pantry_repository.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/product_lookup/data/datasources/open_food_facts_api.dart';
import 'features/product_lookup/data/repositories/cached_product_lookup_repository.dart';
import 'features/product_lookup/domain/repositories/product_lookup_repository.dart';
import 'features/product_lookup/presentation/bloc/product_lookup_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appDb = AppDatabase.instance;
  final pantryRepo = SqlitePantryRepository(appDb);
  final productRepo = CachedProductLookupRepository(
    appDb: appDb,
    api: OpenFoodFactsApi(),
  );

  runApp(
    PantryPalApp(
      pantryRepository: pantryRepo,
      productRepository: productRepo,
    ),
  );
}

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({
    super.key,
    required this.pantryRepository,
    required this.productRepository,
  });

  final PantryRepository pantryRepository;
  final ProductLookupRepository productRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PantryRepository>.value(value: pantryRepository),
        RepositoryProvider<ProductLookupRepository>.value(
          value: productRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => InventoryBloc(pantryRepository)
              ..add(const InventoryStarted()),
          ),
          BlocProvider(
            create: (_) => ProductLookupBloc(
              productRepository: productRepository,
              pantryRepository: pantryRepository,
            ),
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
