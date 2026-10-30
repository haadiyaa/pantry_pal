import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/pantry_category.dart';
import '../../domain/models/pantry_event_reason.dart';
import '../../domain/models/pantry_item.dart';
import '../../../shopping/presentation/cubit/shopping_badge_cubit.dart';
import '../bloc/inventory_bloc.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry Pal'),
        actions: [
          BlocBuilder<InventoryBloc, InventoryState>(
            buildWhen: (prev, curr) =>
                prev.hasActiveFilters != curr.hasActiveFilters,
            builder: (context, state) {
              if (!state.hasActiveFilters) return const SizedBox.shrink();
              return IconButton(
                key: const Key('clear_filters_appbar_button'),
                icon: const Icon(Icons.filter_alt_off),
                tooltip: 'Clear filters',
                onPressed: () => context
                    .read<InventoryBloc>()
                    .add(const InventoryFiltersCleared()),
              );
            },
          ),
          IconButton(
            key: const Key('recipes_button'),
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Recipe Ideas',
            onPressed: () => context.push('/recipes'),
          ),
          BlocBuilder<ShoppingBadgeCubit, int>(
            builder: (context, count) {
              final icon = const Icon(Icons.shopping_cart_outlined);
              return IconButton(
                key: const Key('shopping_list_button'),
                tooltip: 'Shopping List',
                icon: count > 0
                    ? Badge(
                        label: Text('$count'),
                        child: icon,
                      )
                    : icon,
                onPressed: () => context.push('/shopping'),
              );
            },
          ),
          IconButton(
            key: const Key('settings_button'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Isolated Search Bar (owns TextEditingController lifecycle only)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _InventorySearchBar(),
          ),

          // Horizontally Scrollable Filter Chips
          BlocBuilder<InventoryBloc, InventoryState>(
            buildWhen: (prev, curr) =>
                prev.selectedCategories != curr.selectedCategories ||
                prev.expiringSoonOnly != curr.expiringSoonOnly ||
                prev.hasActiveFilters != curr.hasActiveFilters,
            builder: (context, state) {
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (state.hasActiveFilters) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          key: const Key('clear_filters_chip'),
                          avatar: const Icon(
                            Icons.filter_alt_off_outlined,
                            size: 16,
                          ),
                          label: const Text('Clear all'),
                          onPressed: () => context
                              .read<InventoryBloc>()
                              .add(const InventoryFiltersCleared()),
                        ),
                      ),
                    ],
                    // Expiring in 3 days filter
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        key: const Key('expiring_filter_chip'),
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('Expiring in 3 days'),
                        selected: state.expiringSoonOnly,
                        onSelected: (_) {
                          context
                              .read<InventoryBloc>()
                              .add(const InventoryExpiringFilterToggled());
                        },
                      ),
                    ),
                    // Category Filters
                    ...PantryCategory.values.map((cat) {
                      final isSelected =
                          state.selectedCategories.contains(cat.label);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          key: Key('category_filter_chip_${cat.label}'),
                          avatar: Icon(cat.icon, size: 16),
                          label: Text(cat.label),
                          selected: isSelected,
                          onSelected: (_) {
                            context
                                .read<InventoryBloc>()
                                .add(InventoryCategoryToggled(cat.label));
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),

          // Main Inventory Body
          Expanded(
            child: BlocConsumer<InventoryBloc, InventoryState>(
              listener: (context, state) {
                if (state.lastConsumeResult != null) {
                  final result = state.lastConsumeResult!;
                  String message;
                  if (result.event.reason == PantryEventReason.used) {
                    if (result.shoppingItemId != null) {
                      message = 'Added "${result.item.name}" to shopping list';
                    } else if (result.wasRemoved) {
                      message = 'Used up "${result.item.name}"';
                    } else {
                      message =
                          'Used 1 "${result.item.name}" (${result.item.quantity - 1} left)';
                    }
                  } else if (result.event.reason == PantryEventReason.wasted) {
                    message = 'Marked "${result.item.name}" as thrown away';
                  } else {
                    message = 'Deleted "${result.item.name}"';
                  }

                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          context
                              .read<InventoryBloc>()
                              .add(InventoryConsumeUndone(result));
                        },
                      ),
                    ),
                  );
                } else if (state.status == InventoryStatus.failure &&
                    state.items.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(state.errorMessage ?? 'An error occurred'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state.status == InventoryStatus.initial ||
                    state.status == InventoryStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == InventoryStatus.failure &&
                    state.items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.errorMessage ?? 'Something went wrong',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () => context
                              .read<InventoryBloc>()
                              .add(const InventoryStarted()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (state.items.isEmpty) {
                  // Distinct State 1: Total pantry is empty
                  if (state.isPantryEmpty) {
                    final theme = Theme.of(context);
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.kitchen_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your pantry is empty',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + to add an item.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Distinct State 2: Filters active, no results
                  final theme = Theme.of(context);
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items match your filters',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          key: const Key('clear_filters_empty_button'),
                          onPressed: () => context
                              .read<InventoryBloc>()
                              .add(const InventoryFiltersCleared()),
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  );
                }

                // Inventory List
                return ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _ItemTile(item: state.items[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'receipt_fab',
            key: const Key('scan_receipt_fab'),
            tooltip: 'Add from receipt',
            onPressed: () => context.push('/receipt'),
            child: const Icon(Icons.receipt_long),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'scan_fab',
            key: const Key('scan_barcode_fab'),
            tooltip: 'Scan barcode',
            onPressed: () => context.push('/scan'),
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_fab',
            key: const Key('add_item_fab'),
            tooltip: 'Add item manually',
            onPressed: () => context.push('/item/new'),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Small isolated StatefulWidget whose sole responsibility is managing the lifecycle
/// of a [TextEditingController] and disposing it. Holds no business or UI state.
class _InventorySearchBar extends StatefulWidget {
  const _InventorySearchBar();

  @override
  State<_InventorySearchBar> createState() => _InventorySearchBarState();
}

class _InventorySearchBarState extends State<_InventorySearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InventoryBloc, InventoryState>(
      listenWhen: (prev, curr) =>
          prev.searchQuery != curr.searchQuery && curr.searchQuery.isEmpty,
      listener: (context, state) {
        if (_controller.text.isNotEmpty) {
          _controller.clear();
        }
      },
      child: BlocSelector<InventoryBloc, InventoryState, bool>(
        selector: (state) => state.searchQuery.isNotEmpty,
        builder: (context, hasQuery) {
          return TextField(
            key: const Key('inventory_search_field'),
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Search items...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery
                  ? IconButton(
                      key: const Key('clear_search_button'),
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        context
                            .read<InventoryBloc>()
                            .add(const InventorySearchChanged(''));
                      },
                    )
                  : null,
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (query) {
              context
                  .read<InventoryBloc>()
                  .add(InventorySearchChanged(query));
            },
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final PantryItem item;

  Color _color(BuildContext context) => switch (item.freshness) {
        Freshness.fresh => Colors.green,
        Freshness.useSoon => Colors.orange,
        Freshness.expired => Theme.of(context).colorScheme.error,
      };

  String get _label {
    final d = item.daysLeft;
    if (d < 0) return 'Expired ${-d}d ago';
    if (d == 0) return 'Expires today';
    return '$d day${d == 1 ? '' : 's'} left';
  }

  void _showItemOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${item.quantity} in pantry • $_label'),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('item_option_used_up'),
              leading:
                  const Icon(Icons.check_circle_outline, color: Colors.green),
              title: const Text('Used up'),
              subtitle: Text(
                item.quantity > 1
                    ? 'Consume 1 (${item.quantity - 1} remaining)'
                    : 'Consume and add to shopping list',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.read<InventoryBloc>().add(InventoryItemUsedUp(item));
              },
            ),
            ListTile(
              key: const Key('item_option_wasted'),
              leading: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.orange),
              title: const Text('Threw away'),
              subtitle:
                  const Text('Spoiled or wasted (not added to shopping list)'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.read<InventoryBloc>().add(InventoryItemWasted(item));
              },
            ),
            ListTile(
              key: const Key('item_option_deleted'),
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Remove mistake (not recorded as waste)'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (item.id != null) {
                  context
                      .read<InventoryBloc>()
                      .add(InventoryItemDeleted(item.id!));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = PantryCategory.fromString(item.category);

    return Dismissible(
      key: ValueKey('pantry_tile_${item.id ?? item.name}'),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.green.shade700,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Used up',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline,
                color: theme.colorScheme.onErrorContainer),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (item.quantity > 1) {
            context.read<InventoryBloc>().add(InventoryItemUsedUp(item));
            return false;
          }
          return true;
        }
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          context.read<InventoryBloc>().add(InventoryItemUsedUp(item));
        } else {
          if (item.id != null) {
            context.read<InventoryBloc>().add(InventoryItemDeleted(item.id!));
          }
        }
      },
      child: ListTile(
        leading: Badge(
          backgroundColor: _color(context),
          smallSize: 10,
          child: CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              category.icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${category.label} • ${DateFormat.yMMMd().format(item.expiryDate)} • $_label'
          '${item.notes != null && item.notes!.isNotEmpty ? '\n${item.notes}' : ''}',
        ),
        isThreeLine: item.notes != null && item.notes!.isNotEmpty,
        trailing: Text(
          'x${item.quantity}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => context.push('/item/${item.id}', extra: item),
        onLongPress: () => _showItemOptions(context),
      ),
    );
  }
}
