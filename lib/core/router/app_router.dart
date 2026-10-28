import 'package:go_router/go_router.dart';

import '../../features/inventory/domain/models/pantry_item.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/inventory/presentation/pages/item_form_page.dart';
import '../../features/product_lookup/presentation/pages/scanner_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'inventory',
      builder: (context, state) => const InventoryPage(),
    ),
    GoRoute(
      path: '/scan',
      name: 'scanner',
      builder: (context, state) => const ScannerPage(),
    ),
    GoRoute(
      path: '/item/new',
      name: 'item-new',
      builder: (context, state) {
        final prefilledItem = state.extra as PantryItem?;
        return ItemFormPage(initialItem: prefilledItem);
      },
    ),
    GoRoute(
      path: '/item/:id',
      name: 'item-edit',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        final item = state.extra as PantryItem?;
        return ItemFormPage(itemId: id, initialItem: item);
      },
    ),
  ],
);
