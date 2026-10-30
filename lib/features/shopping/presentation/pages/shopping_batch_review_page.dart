import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../inventory/domain/models/pantry_category.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../../notifications/domain/services/notification_sync_service.dart';
import '../../domain/models/shopping_item.dart';
import '../../domain/repositories/shopping_repository.dart';
import '../cubit/shopping_batch_review_cubit.dart';
import '../cubit/shopping_batch_review_item.dart';
import '../cubit/shopping_batch_review_state.dart';

class ShoppingBatchReviewPage extends StatelessWidget {
  const ShoppingBatchReviewPage({
    super.key,
    this.boughtItems,
  });

  final List<ShoppingItem>? boughtItems;

  @override
  Widget build(BuildContext context) {
    NotificationSyncService? syncService;
    try {
      syncService = context.read<NotificationSyncService>();
    } catch (_) {
      syncService = null;
    }

    return BlocProvider(
      create: (context) => ShoppingBatchReviewCubit(
        shoppingRepository: context.read<ShoppingRepository>(),
        pantryRepository: context.read<PantryRepository>(),
        notificationSyncService: syncService,
        boughtItems: boughtItems,
      ),
      child: const _ShoppingBatchReviewView(),
    );
  }
}

class _ShoppingBatchReviewView extends StatelessWidget {
  const _ShoppingBatchReviewView();

  Future<void> _pickExpiryDate(
    BuildContext context,
    ShoppingBatchReviewItem item,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null && context.mounted) {
      context
          .read<ShoppingBatchReviewCubit>()
          .expiryDateChanged(item.shoppingItemId, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<ShoppingBatchReviewCubit, ShoppingBatchReviewState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ShoppingBatchReviewStatus.success) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added bought items to your pantry!'),
            ),
          );
          Navigator.of(context).pop();
        } else if (state.status == ShoppingBatchReviewStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.errorMessage ?? 'Failed to move items to pantry',
              ),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<ShoppingBatchReviewCubit>();
        final includedCount = state.includedCount;
        final isSubmitting =
            state.status == ShoppingBatchReviewStatus.submitting;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Move to Pantry'),
          ),
          body: state.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No bought items to review',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to Shopping List'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: state.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return _ReviewItemCard(
                      item: item,
                      onToggleIncluded: () =>
                          cubit.toggleIncluded(item.shoppingItemId),
                      onNameChanged: (val) =>
                          cubit.nameChanged(item.shoppingItemId, val),
                      onCategoryChanged: (val) =>
                          cubit.categoryChanged(item.shoppingItemId, val),
                      onQuantityChanged: (val) =>
                          cubit.quantityChanged(item.shoppingItemId, val),
                      onPickExpiryDate: () => _pickExpiryDate(context, item),
                    );
                  },
                ),
          bottomSheet: state.items.isEmpty
              ? null
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: FilledButton.icon(
                      key: const Key('confirm_add_to_pantry_button'),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        isSubmitting
                            ? 'Adding to pantry...'
                            : 'Add $includedCount item${includedCount == 1 ? '' : 's'} to pantry',
                      ),
                      onPressed: (includedCount > 0 && !isSubmitting)
                          ? () => cubit.saveToPantry()
                          : null,
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _ReviewItemCard extends StatelessWidget {
  const _ReviewItemCard({
    required this.item,
    required this.onToggleIncluded,
    required this.onNameChanged,
    required this.onCategoryChanged,
    required this.onQuantityChanged,
    required this.onPickExpiryDate,
  });

  final ShoppingBatchReviewItem item;
  final VoidCallback onToggleIncluded;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onPickExpiryDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = PantryCategory.fromString(item.category);

    return Card(
      elevation: item.isIncluded ? 1 : 0,
      color: item.isIncluded
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isIncluded
              ? theme.colorScheme.outlineVariant
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkbox, Name, Quantity
            Row(
              children: [
                Checkbox(
                  value: item.isIncluded,
                  onChanged: (_) => onToggleIncluded(),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: item.name,
                    enabled: item.isIncluded,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Item name',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration:
                          item.isIncluded ? null : TextDecoration.lineThrough,
                    ),
                    onChanged: onNameChanged,
                  ),
                ),
                // Quantity Stepper
                if (item.isIncluded) ...[
                  IconButton.outlined(
                    icon: const Icon(Icons.remove, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: item.quantity > 1
                        ? () => onQuantityChanged(item.quantity - 1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQuantityChanged(item.quantity + 1),
                  ),
                ],
              ],
            ),

            if (item.isIncluded) ...[
              const Divider(height: 16),
              // Bottom Row: Category selector and Expiry Date Picker
              Row(
                children: [
                  // Category Dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: item.category,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(category.icon, size: 18),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: PantryCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat.label,
                          child: Text(
                            cat.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) onCategoryChanged(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Expiry Date Chip
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat.MMMd().format(item.expiryDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          item.isEstimated ? 'Estimated' : 'Picked',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    onPressed: onPickExpiryDate,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

