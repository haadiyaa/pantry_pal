import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/inventory/domain/models/pantry_item.dart';
import '../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/inventory/presentation/pages/item_form_page.dart';
import '../../features/notifications/presentation/pages/notification_settings_page.dart';
import '../../features/product_lookup/presentation/pages/scanner_page.dart';
import '../../features/receipt/domain/models/receipt_draft.dart';
import '../../features/receipt/presentation/pages/receipt_review_page.dart';
import '../../features/receipt/presentation/pages/receipt_scan_page.dart';
import '../../features/recipes/presentation/pages/recipe_detail_page.dart';
import '../../features/recipes/presentation/pages/recipes_page.dart';
import '../../features/shopping/domain/models/shopping_item.dart';
import '../../features/shopping/presentation/pages/shopping_batch_review_page.dart';
import '../../features/shopping/presentation/pages/shopping_list_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'inventory',
      builder: (context, state) {
        final filter = state.uri.queryParameters['filter'];
        if (filter == 'expiring') {
          try {
            final bloc = context.read<InventoryBloc>();
            if (!bloc.state.expiringSoonOnly) {
              bloc.add(const InventoryExpiringFilterToggled());
            }
          } catch (_) {}
        }
        return const InventoryPage();
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const NotificationSettingsPage(),
    ),
    GoRoute(
      path: '/scan',
      name: 'scanner',
      builder: (context, state) => const ScannerPage(),
    ),
    GoRoute(
      path: '/receipt',
      name: 'receipt-scan',
      builder: (context, state) => const ReceiptScanPage(),
    ),
    GoRoute(
      path: '/receipt/review',
      name: 'receipt-review',
      builder: (context, state) {
        final draft = state.extra as ReceiptDraft?;
        return ReceiptReviewPage(draft: draft);
      },
    ),
    GoRoute(
      path: '/recipes',
      name: 'recipes',
      builder: (context, state) => const RecipesPage(),
    ),
    GoRoute(
      path: '/recipes/:id',
      name: 'recipe-detail',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return RecipeDetailPage(recipeId: id);
      },
    ),
    GoRoute(
      path: '/shopping',
      name: 'shopping',
      builder: (context, state) => const ShoppingListPage(),
    ),
    GoRoute(
      path: '/shopping/review',
      name: 'shopping-review',
      builder: (context, state) {
        final bought = state.extra as List<ShoppingItem>?;
        return ShoppingBatchReviewPage(boughtItems: bought);
      },
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
