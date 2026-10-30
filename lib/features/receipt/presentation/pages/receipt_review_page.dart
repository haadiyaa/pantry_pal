import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../inventory/domain/models/pantry_category.dart';
import '../../../inventory/domain/repositories/pantry_repository.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../notifications/domain/services/notification_sync_service.dart';
import '../../domain/models/receipt_draft.dart';
import '../../domain/services/receipt_parser.dart';
import '../cubit/receipt_review_cubit.dart';
import '../cubit/receipt_review_item.dart';
import '../cubit/receipt_review_state.dart';

class ReceiptReviewPage extends StatelessWidget {
  const ReceiptReviewPage({super.key, this.draft});

  final ReceiptDraft? draft;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        NotificationSyncService? syncService;
        try {
          syncService = context.read<NotificationSyncService>();
        } catch (_) {
          syncService = null;
        }
        final cubit = ReceiptReviewCubit(
          pantryRepository: context.read<PantryRepository>(),
          notificationSyncService: syncService,
        );
        if (draft != null) {
          cubit.initialize(draft!);
        }
        return cubit;
      },
      child: const _ReceiptReviewView(),
    );
  }
}

class _ReceiptReviewView extends StatelessWidget {
  const _ReceiptReviewView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ReceiptReviewCubit>();

    return BlocConsumer<ReceiptReviewCubit, ReceiptReviewState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ReceiptReviewStatus.saveSuccess) {
          context.read<InventoryBloc>().add(const InventoryStarted());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully added ${state.savedCount} items to your pantry!',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
          context.go('/');
        } else if (state.status == ReceiptReviewStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Failed to save items'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == ReceiptReviewStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final items = state.items;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Review Receipt Items'),
            actions: [
              IconButton(
                key: const Key('add_manual_row_appbar_button'),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add item manually',
                onPressed: state.isSaving ? null : cubit.addItem,
              ),
            ],
          ),
          body: Column(
            children: [
              // Summary and Header Bar
              _buildHeader(context, state, cubit, theme),

              // Error banner if any
              if (state.errorMessage != null &&
                  state.status != ReceiptReviewStatus.failure)
                Container(
                  color: theme.colorScheme.errorContainer,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),

              // Items List
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('No items to display'),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Row Manually'),
                              onPressed: cubit.addItem,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ReceiptItemCard(
                            key: ValueKey(item.id),
                            item: item,
                          );
                        },
                      ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, state, cubit, theme),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ReceiptReviewState state,
    ReceiptReviewCubit cubit,
    ThemeData theme,
  ) {
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Found ${state.totalCount} items',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (state.receiptDate != null)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    'Receipt: ${DateFormat.yMMMd().format(state.receiptDate!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated shelf-life dates prefilled. Adjust any details before saving.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                key: const Key('select_all_button'),
                icon: Icon(
                  state.allSelected
                      ? Icons.deselect_outlined
                      : Icons.select_all_outlined,
                  size: 18,
                ),
                label: Text(state.allSelected ? 'Deselect All' : 'Select All'),
                onPressed: () => cubit.selectAll(!state.allSelected),
              ),
              const Spacer(),
              TextButton.icon(
                key: const Key('add_item_review_button'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Missing Item'),
                onPressed: state.isSaving ? null : cubit.addItem,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ReceiptReviewState state,
    ReceiptReviewCubit cubit,
    ThemeData theme,
  ) {
    return Surface(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton(
            key: const Key('save_receipt_items_button'),
            onPressed: (state.includedCount == 0 || state.isSaving)
                ? null
                : cubit.saveAll,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: state.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save ${state.includedCount} Items to Pantry',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptItemCard extends StatelessWidget {
  const _ReceiptItemCard({super.key, required this.item});

  final ReceiptReviewItem item;

  Future<void> _pickExpiryDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && context.mounted) {
      context.read<ReceiptReviewCubit>().updateExpiryDate(item.id, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ReceiptReviewCubit>();
    final isLowConfidence = item.isLowConfidence;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLowConfidence
            ? BorderSide(color: Colors.amber.shade700, width: 2)
            : BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(80),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badges (Low confidence or Duplicate warning)
            if (isLowConfidence || item.isDuplicate) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isLowConfidence)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 14, color: Colors.amber.shade900),
                          const SizedBox(width: 4),
                          Text(
                            'Low Confidence - Please Check',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.isDuplicate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Already in pantry (x${item.existingItemQuantity})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Row 1: Include Checkbox, Name Field, Delete Button
            Row(
              children: [
                Checkbox(
                  key: Key('checkbox_${item.id}'),
                  value: item.isIncluded,
                  onChanged: (_) => cubit.toggleInclude(item.id),
                ),
                Expanded(
                  child: TextFormField(
                    key: Key('name_field_${item.id}'),
                    initialValue: item.name,
                    decoration: const InputDecoration(
                      labelText: 'Item name *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => cubit.updateName(item.id, val),
                  ),
                ),
                IconButton(
                  key: Key('delete_button_${item.id}'),
                  icon: const Icon(Icons.delete_outline),
                  color: theme.colorScheme.error,
                  tooltip: 'Delete item',
                  onPressed: () => cubit.deleteItem(item.id),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Quantity Stepper, Price Field
            Row(
              children: [
                // Quantity Stepper
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('decrement_qty_${item.id}'),
                        icon: const Icon(Icons.remove, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: item.quantity > 1
                            ? () => cubit.updateQuantity(
                                item.id, item.quantity - 1)
                            : null,
                      ),
                      Text(
                        '${item.quantity}',
                        key: Key('qty_text_${item.id}'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        key: Key('increment_qty_${item.id}'),
                        icon: const Icon(Icons.add, size: 16),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            cubit.updateQuantity(item.id, item.quantity + 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Price Field
                Expanded(
                  child: TextFormField(
                    key: Key('price_field_${item.id}'),
                    initialValue: item.priceInPaise != null
                        ? (item.priceInPaise! / 100).toStringAsFixed(2)
                        : '',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '₹ ',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final paise = ReceiptParser.parseMoneyToPaise(val);
                      cubit.updatePrice(item.id, paise);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3: Category Dropdown & Expiry Date Chip
            Row(
              children: [
                // Category Dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    key: Key('category_dropdown_${item.id}'),
                    initialValue: PantryCategory.values
                            .any((c) => c.label == item.category)
                        ? item.category
                        : 'Other',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: PantryCategory.values.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.label,
                        child: Text(c.label, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) cubit.updateCategory(item.id, val);
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Expiry Date Chip
                Expanded(
                  flex: 3,
                  child: InkWell(
                    key: Key('expiry_picker_${item.id}'),
                    onTap: () => _pickExpiryDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Est. Expiry',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        DateFormat.yMMMd().format(item.expiryDate),
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // If duplicate: Choice to merge or add as separate item
            if (item.isDuplicate) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Duplicate Action: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ChoiceChip(
                    label: const Text('Add Separate', style: TextStyle(fontSize: 11)),
                    selected: item.duplicateResolution ==
                        DuplicateResolution.addAsNew,
                    onSelected: (_) => cubit.setDuplicateResolution(
                        item.id, DuplicateResolution.addAsNew),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: Key('merge_chip_${item.id}'),
                    label: Text('+${item.quantity} to Existing',
                        style: const TextStyle(fontSize: 11)),
                    selected: item.duplicateResolution ==
                        DuplicateResolution.incrementExisting,
                    onSelected: (_) => cubit.setDuplicateResolution(
                        item.id, DuplicateResolution.incrementExisting),
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

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
