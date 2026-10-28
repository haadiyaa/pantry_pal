import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'features/inventory/data/repositories/sqlite_pantry_repository.dart';
import 'features/inventory/domain/repositories/pantry_repository.dart';
import 'features/inventory/presentation/bloc/inventory_bloc.dart';
import 'features/inventory/presentation/pages/inventory_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    PantryPalApp(
      repository: SqlitePantryRepository(AppDatabase.instance),
    ),
  );
}

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key, required this.repository});

  final PantryRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<PantryRepository>.value(
      value: repository,
      child: BlocProvider(
        create: (_) => InventoryBloc(repository)..add(const InventoryStarted()),
        child: MaterialApp(
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
          home: const InventoryPage(),
        ),
      ),
    );
  }
}
