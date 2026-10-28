import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/pantry_category.dart';
import '../../domain/models/pantry_item.dart';
import '../bloc/inventory_bloc.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pantry Pal')),
      body: BlocConsumer<InventoryBloc, InventoryState>(
        listener: (context, state) {
          if (state.status == InventoryStatus.failure &&
              state.items.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'An error occurred'),
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

          if (state.status == InventoryStatus.failure && state.items.isEmpty) {
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
            return const Center(
              child: Text('Your pantry is empty. Tap + to add an item.'),
            );
          }

          return ListView.separated(
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ItemTile(item: state.items[i]),
          );
        },
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
          '${category.label} • ${DateFormat.yMMMd().format(item.expiryDate)} • $_label',
        ),
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
