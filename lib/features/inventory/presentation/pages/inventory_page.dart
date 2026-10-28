import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/pantry_category.dart';
import '../../domain/models/pantry_item.dart';
import '../bloc/inventory_bloc.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAllFilters(BuildContext context) {
    _searchController.clear();
    context.read<InventoryBloc>().add(const InventoryFiltersCleared());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                onPressed: () => _clearAllFilters(context),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('inventory_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        key: const Key('clear_search_button'),
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context
                              .read<InventoryBloc>()
                              .add(const InventorySearchChanged(''));
                          setState(() {});
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
                setState(() {});
                context
                    .read<InventoryBloc>()
                    .add(InventorySearchChanged(query));
              },
            ),
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
                          onPressed: () => _clearAllFilters(context),
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
                if (state.status == InventoryStatus.failure &&
                    state.items.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(state.errorMessage ?? 'An error occurred'),
                      backgroundColor: theme.colorScheme.error,
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
                          style: TextStyle(color: theme.colorScheme.error),
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
                          onPressed: () => _clearAllFilters(context),
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
      floatingActionButton: FloatingActionButton(
        key: const Key('add_item_fab'),
        onPressed: () => context.push('/item/new'),
        child: const Icon(Icons.add),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = PantryCategory.fromString(item.category);

    return Dismissible(
      key: ValueKey(item.id ?? item.name),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        if (item.id != null) {
          final deletedItem = item;
          context.read<InventoryBloc>().add(InventoryItemDeleted(deletedItem.id!));
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${deletedItem.name}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  context
                      .read<InventoryBloc>()
                      .add(InventoryItemAdded(deletedItem));
                },
              ),
            ),
          );
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
      ),
    );
  }
}
