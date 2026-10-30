import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../inventory/domain/models/pantry_category.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../bloc/shopping_list_bloc.dart';
import '../bloc/shopping_list_event.dart';
import '../bloc/shopping_list_state.dart';

class ShoppingListPage extends StatelessWidget {
  const ShoppingListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ShoppingListBloc(
        shoppingRepository: context.read<ShoppingRepository>(),
        pantryRepository: context.read<PantryRepository>(),
      )..add(const ShoppingListStarted()),
      child: const _ShoppingListView(),
    );
  }
}

class _ShoppingListView extends StatelessWidget {
  const _ShoppingListView();

  void _showPantryWarningDialog(
    BuildContext context,
    ShoppingItem candidate,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Already in Pantry'),
        content: Text(
          'You already have "${candidate.name}" in your pantry. Do you still want to add it to your shopping list?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context
                  .read<ShoppingListBloc>()
                  .add(const ShoppingListDismissPantryWarning());
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ShoppingListBloc>().add(
                    ShoppingListManualItemAdded(
                      name: candidate.name,
                      category: candidate.category,
                      quantity: candidate.quantity,
                      forceAdd: true,
                    ),
                  );
            },
            child: const Text('Add anyway'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(BuildContext context, ShoppingItem item) {
    final nameController = TextEditingController(text: item.name);
    var category = item.category;
    var quantity = item.quantity;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Shopping Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: PantryCategory.values.map((cat) {
                  return DropdownMenuItem(
                    value: cat.label,
                    child: Row(
                      children: [
                        Icon(cat.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(cat.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => category = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quantity:'),
                  Row(
                    children: [
                      IconButton.outlined(
                        icon: const Icon(Icons.remove),
                        onPressed: quantity > 1
                            ? () => setDialogState(() => quantity--)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        icon: const Icon(Icons.add),
                        onPressed: () => setDialogState(() => quantity++),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  context.read<ShoppingListBloc>().add(
                        ShoppingListItemEdited(
                          item.copyWith(
                            name: newName,
                            category: category,
                            quantity: quantity,
                          ),
                        ),
                      );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ShoppingListBloc, ShoppingListState>(
      listenWhen: (prev, curr) =>
          prev.lastDeletedItem != curr.lastDeletedItem ||
          prev.lastClearedBought != curr.lastClearedBought ||
          prev.errorMessage != curr.errorMessage ||
          prev.pantryWarningItem != curr.pantryWarningItem,
      listener: (context, state) {
        if (state.pantryWarningItem != null) {
          _showPantryWarningDialog(context, state.pantryWarningItem!);
        }

        if (state.lastDeletedItem != null) {
          final deletedItem = state.lastDeletedItem!;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${deletedItem.name}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  context
                      .read<ShoppingListBloc>()
                      .add(ShoppingListUndoDelete(deletedItem));
                },
              ),
            ),
          );
        }

        if (state.lastClearedBought != null) {
          final cleared = state.lastClearedBought!;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleared ${cleared.length} bought items'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  context
                      .read<ShoppingListBloc>()
                      .add(ShoppingListUndoClearBought(cleared));
                },
              ),
            ),
          );
        }

        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final uncheckedCategories = state.groupedList.uncheckedCategories;
        final boughtItems = state.groupedList.boughtItems;
        final hasItems = state.items.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Shopping List'),
            actions: [
              if (hasItems)
                IconButton(
                  key: const Key('share_shopping_list_button'),
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share list',
                  onPressed: () {
                    context
                        .read<ShoppingListBloc>()
                        .add(const ShoppingListShareRequested());
                  },
                ),
              if (boughtItems.isNotEmpty)
                IconButton(
                  key: const Key('clear_bought_button'),
                  icon: const Icon(Icons.playlist_remove),
                  tooltip: 'Clear bought items',
                  onPressed: () {
                    context
                        .read<ShoppingListBloc>()
                        .add(const ShoppingListClearBought());
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // Quick-Add Input Row
              const _ShoppingQuickAddBar(),
              const Divider(height: 1),

              // Content Area
              Expanded(
                child: state.status == ShoppingListStatus.loading && !hasItems
                    ? const Center(child: CircularProgressIndicator())
                    : !hasItems
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Your shopping list is empty',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add items above, use up pantry items, or add missing ingredients from recipes.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.restaurant_menu),
                                    label: const Text('Browse Recipes'),
                                    onPressed: () => context.push('/recipes'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.only(bottom: 32),
                            children: [
                              // Unchecked Items Grouped by Category
                              for (final entry in uncheckedCategories.entries) ...[
                                _CategoryHeader(
                                  categoryName: entry.key,
                                  count: entry.value.length,
                                ),
                                for (final item in entry.value)
                                  _ShoppingItemTile(
                                    key: ValueKey('shopping_${item.id}'),
                                    item: item,
                                    onEdit: () =>
                                        _showEditItemDialog(context, item),
                                  ),
                              ],

                              // Bought Section
                              if (boughtItems.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Bought (${boughtItems.length})',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        key: const Key(
                                            'clear_bought_text_button'),
                                        icon: const Icon(Icons.clear, size: 16),
                                        label: const Text('Clear'),
                                        onPressed: () {
                                          context.read<ShoppingListBloc>().add(
                                                const ShoppingListClearBought(),
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: FilledButton.icon(
                                    key: const Key('move_bought_to_pantry_button'),
                                    icon: const Icon(Icons.kitchen),
                                    label: Text(
                                      'Add ${boughtItems.length} bought item${boughtItems.length == 1 ? '' : 's'} to pantry',
                                    ),
                                    onPressed: () =>
                                        context.push('/shopping/review'),
                                  ),
                                ),
                                for (final item in boughtItems)
                                  _BoughtItemTile(
                                    key: ValueKey('bought_${item.id}'),
                                    item: item,
                                  ),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.categoryName,
    required this.count,
  });

  final String categoryName;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = PantryCategory.fromString(categoryName);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            category.icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            category.label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    super.key,
    required this.item,
    required this.onEdit,
  });

  final ShoppingItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('dismiss_shopping_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
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
            Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        if (item.id != null) {
          context
              .read<ShoppingListBloc>()
              .add(ShoppingListItemDeleted(item.id!));
        }
      },
      child: ListTile(
        leading: Checkbox(
          value: item.isBought,
          onChanged: (val) {
            if (item.id != null && val != null) {
              context
                  .read<ShoppingListBloc>()
                  .add(ShoppingListItemBoughtToggled(id: item.id!, isBought: val));
            }
          },
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.sourceLabel ?? 'Manual',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.quantity > 1)
              Text(
                'x${item.quantity}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit item',
            ),
          ],
        ),
      ),
    );
  }
}

class _BoughtItemTile extends StatelessWidget {
  const _BoughtItemTile({
    super.key,
    required this.item,
  });

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('dismiss_bought_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) {
        if (item.id != null) {
          context
              .read<ShoppingListBloc>()
              .add(ShoppingListItemDeleted(item.id!));
        }
      },
      child: ListTile(
        leading: Checkbox(
          value: true,
          onChanged: (val) {
            if (item.id != null && val != null) {
              context
                  .read<ShoppingListBloc>()
                  .add(ShoppingListItemBoughtToggled(id: item.id!, isBought: val));
            }
          },
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        subtitle: Text(
          item.sourceLabel ?? 'Manual',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        trailing: item.quantity > 1
            ? Text(
                'x${item.quantity}',
                style: TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              )
            : null,
      ),
    );
  }
}

/// Small isolated widget for managing the quick-add text editing controller and category state.
class _ShoppingQuickAddBar extends StatefulWidget {
  const _ShoppingQuickAddBar();

  @override
  State<_ShoppingQuickAddBar> createState() => _ShoppingQuickAddBarState();
}

class _ShoppingQuickAddBarState extends State<_ShoppingQuickAddBar> {
  late final TextEditingController _controller;
  String _category = PantryCategory.other.label;
  int _quantity = 1;

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

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    context.read<ShoppingListBloc>().add(
          ShoppingListManualItemAdded(
            name: name,
            category: _category,
            quantity: _quantity,
          ),
        );

    _controller.clear();
    setState(() {
      _quantity = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('shopping_quick_add_input'),
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Add an item...',
                isDense: true,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: PopupMenuButton<String>(
                  key: const Key('shopping_category_menu_button'),
                  tooltip: 'Select category: $_category',
                  icon: Icon(
                    PantryCategory.fromString(_category).icon,
                    size: 20,
                  ),
                  onSelected: (cat) => setState(() => _category = cat),
                  itemBuilder: (context) => PantryCategory.values.map((cat) {
                    return PopupMenuItem(
                      value: cat.label,
                      child: Row(
                        children: [
                          Icon(cat.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(cat.label),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const Key('shopping_quick_add_button'),
            icon: const Icon(Icons.add),
            tooltip: 'Add item',
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
