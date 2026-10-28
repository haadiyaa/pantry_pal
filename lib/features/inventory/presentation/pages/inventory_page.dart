import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/models/pantry_item.dart';
import '../bloc/inventory_bloc.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  Future<void> _addItem(BuildContext context) async {
    final bloc = context.read<InventoryBloc>();
    final name = await _askName(context);
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    final expiry = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (expiry == null) return;

    bloc.add(
      InventoryItemAdded(
        PantryItem(
          name: name.trim(),
          expiryDate: expiry,
          addedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<String?> _askName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

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
        onPressed: () => _addItem(context),
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
    return Dismissible(
      key: ValueKey(item.id ?? item.name),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) {
        if (item.id != null) {
          context.read<InventoryBloc>().add(InventoryItemDeleted(item.id!));
        }
      },
      child: ListTile(
        leading: CircleAvatar(backgroundColor: _color(context), radius: 8),
        title: Text(item.name),
        subtitle: Text(
          '${DateFormat.yMMMd().format(item.expiryDate)} • $_label',
        ),
        trailing: Text('x${item.quantity}'),
      ),
    );
  }
}
