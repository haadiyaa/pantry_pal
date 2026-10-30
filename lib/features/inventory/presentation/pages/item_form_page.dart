import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/pantry_category.dart';
import '../../domain/models/pantry_item.dart';
import '../../domain/repositories/pantry_repository.dart';
import '../bloc/inventory_bloc.dart';
import '../cubit/item_form_cubit.dart';
import '../cubit/item_form_state.dart';

class ItemFormPage extends StatelessWidget {
  const ItemFormPage({
    super.key,
    this.itemId,
    this.initialItem,
  });

  final int? itemId;
  final PantryItem? initialItem;

  @override
  Widget build(BuildContext context) {
    PantryItem? resolvedItem = initialItem;
    if (resolvedItem == null && itemId != null) {
      final items = context.read<InventoryBloc>().state.items;
      try {
        resolvedItem = items.firstWhere((i) => i.id == itemId);
      } catch (_) {
        resolvedItem = null;
      }
    }

    return BlocProvider(
      create: (context) => ItemFormCubit(
        repository: context.read<PantryRepository>(),
        initialItem: resolvedItem,
      ),
      child: const _ItemFormView(),
    );
  }
}

class _ItemFormView extends StatelessWidget {
  const _ItemFormView();

  Future<void> _selectExpiryDate(
    BuildContext context,
    DateTime currentExpiry,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentExpiry,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && context.mounted) {
      context.read<ItemFormCubit>().expiryDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ItemFormCubit>();
    final isEditing = cubit.state.isEditing;
    final initialItem = cubit.state.initialItem;

    return BlocListener<ItemFormCubit, ItemFormState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ItemFormStatus.success) {
          context.read<InventoryBloc>().add(const InventoryStarted());
          if (context.mounted) {
            try {
              context.pop();
            } catch (_) {
              Navigator.of(context).maybePop();
            }
          }
        } else if (state.status == ItemFormStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Failed to save item'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Item' : 'Add Item'),
          actions: [
            if (isEditing && initialItem != null)
              PopupMenuButton<String>(
                key: const Key('item_form_actions_menu'),
                icon: const Icon(Icons.more_vert),
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'used_up') {
                    context
                        .read<InventoryBloc>()
                        .add(InventoryItemUsedUp(initialItem));
                    Navigator.of(context).pop();
                  } else if (value == 'wasted') {
                    context
                        .read<InventoryBloc>()
                        .add(InventoryItemWasted(initialItem));
                    Navigator.of(context).pop();
                  } else if (value == 'delete') {
                    if (initialItem.id != null) {
                      context
                          .read<InventoryBloc>()
                          .add(InventoryItemDeleted(initialItem.id!));
                    }
                    Navigator.of(context).pop();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    key: Key('item_form_action_used_up'),
                    value: 'used_up',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Mark as Used up'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    key: Key('item_form_action_wasted'),
                    value: 'wasted',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined,
                            color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Mark as Threw away'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    key: const Key('item_form_action_delete'),
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            color: theme.colorScheme.error),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Item Name Field
              BlocSelector<ItemFormCubit, ItemFormState, String?>(
                selector: (state) => state.nameError,
                builder: (context, nameError) {
                  return TextFormField(
                    key: const Key('item_name_field'),
                    initialValue: cubit.state.name,
                    autofocus: !isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Item name *',
                      hintText: 'e.g. Greek Yogurt',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      errorText: nameError,
                    ),
                    onChanged: cubit.nameChanged,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Category Selector
              BlocSelector<ItemFormCubit, ItemFormState, PantryCategory>(
                selector: (state) => state.category,
                builder: (context, category) {
                  return DropdownButtonFormField<PantryCategory>(
                    key: const Key('item_category_field'),
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: PantryCategory.values.map((cat) {
                      return DropdownMenuItem<PantryCategory>(
                        value: cat,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(cat.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (cat) {
                      if (cat != null) {
                        cubit.categoryChanged(cat);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Quantity Stepper
              BlocSelector<ItemFormCubit, ItemFormState, int>(
                selector: (state) => state.quantity,
                builder: (context, quantity) {
                  return Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity',
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                'Must be at least 1',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton.outlined(
                                key: const Key('quantity_decrement_button'),
                                icon: const Icon(Icons.remove),
                                onPressed: quantity > 1
                                    ? cubit.quantityDecremented
                                    : null,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$quantity',
                                  key: const Key('quantity_value_text'),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton.outlined(
                                key: const Key('quantity_increment_button'),
                                icon: const Icon(Icons.add),
                                onPressed: cubit.quantityIncremented,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Expiry Date Picker Card
              BlocSelector<ItemFormCubit, ItemFormState, DateTime>(
                selector: (state) => state.expiryDate,
                builder: (context, expiryDate) {
                  return Card.outlined(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Expiry date'),
                      subtitle: Text(
                        DateFormat.yMMMd().format(expiryDate),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.edit_calendar),
                        label: const Text('Change'),
                        onPressed: () =>
                            _selectExpiryDate(context, expiryDate),
                      ),
                      onTap: () => _selectExpiryDate(context, expiryDate),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Optional Price Field
              BlocSelector<ItemFormCubit, ItemFormState, String?>(
                selector: (state) => state.priceError,
                builder: (context, priceError) {
                  return TextFormField(
                    key: const Key('item_price_field'),
                    initialValue: cubit.state.priceText,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price (optional)',
                      hintText: 'e.g. 45.50',
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.currency_rupee_outlined),
                      errorText: priceError,
                    ),
                    onChanged: cubit.priceChanged,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Optional Notes Field
              TextFormField(
                key: const Key('item_notes_field'),
                initialValue: cubit.state.notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. Opened on Monday, keep chilled',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                onChanged: cubit.notesChanged,
              ),
              const SizedBox(height: 16),

              // Optional Barcode Field
              TextFormField(
                key: const Key('item_barcode_field'),
                initialValue: cubit.state.barcode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Barcode (optional)',
                  hintText: 'e.g. 737628064502',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_scanner_outlined),
                ),
                onChanged: cubit.barcodeChanged,
              ),
              const SizedBox(height: 24),

              // Save Button with loading state via BlocSelector
              BlocSelector<ItemFormCubit, ItemFormState,
                  (bool isSubmitting, bool isEditing)>(
                selector: (state) => (
                  state.status == ItemFormStatus.submitting,
                  state.isEditing
                ),
                builder: (context, data) {
                  final (isSubmitting, isEditingState) = data;

                  return FilledButton(
                    key: const Key('save_item_button'),
                    onPressed: isSubmitting ? null : cubit.submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditingState ? 'Save Changes' : 'Add Item',
                            style: const TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
