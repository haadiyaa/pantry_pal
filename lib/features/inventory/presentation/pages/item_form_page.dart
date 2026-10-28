import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/pantry_category.dart';
import '../../domain/models/pantry_item.dart';
import '../bloc/inventory_bloc.dart';

class ItemFormPage extends StatefulWidget {
  const ItemFormPage({
    super.key,
    this.itemId,
    this.initialItem,
  });

  final int? itemId;
  final PantryItem? initialItem;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _barcodeController;

  late PantryCategory _category;
  late int _quantity;
  late DateTime _expiryDate;
  PantryItem? _existingItem;
  bool _isSaving = false;

  bool get _isEditing => _existingItem != null;

  @override
  void initState() {
    super.initState();

    _existingItem = widget.initialItem;
    if (_existingItem == null && widget.itemId != null) {
      final items = context.read<InventoryBloc>().state.items;
      try {
        _existingItem = items.firstWhere((i) => i.id == widget.itemId);
      } catch (_) {
        _existingItem = null;
      }
    }

    _nameController = TextEditingController(text: _existingItem?.name ?? '');
    _barcodeController =
        TextEditingController(text: _existingItem?.barcode ?? '');
    _category = PantryCategory.fromString(_existingItem?.category);
    _quantity = _existingItem?.quantity ?? 1;
    _expiryDate = _existingItem?.expiryDate ??
        DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_quantity < 1) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final barcode = _barcodeController.text.trim();

    if (_isEditing) {
      final updated = _existingItem!.copyWith(
        name: name,
        quantity: _quantity,
        category: _category.label,
        expiryDate: _expiryDate,
        barcode: barcode.isEmpty ? null : barcode,
      );
      context.read<InventoryBloc>().add(InventoryItemUpdated(updated));
    } else {
      final newItem = PantryItem(
        name: name,
        quantity: _quantity,
        category: _category.label,
        expiryDate: _expiryDate,
        barcode: barcode.isEmpty ? null : barcode,
        addedAt: DateTime.now(),
      );
      context.read<InventoryBloc>().add(InventoryItemAdded(newItem));
    }

    if (mounted) {
      try {
        context.pop();
      } catch (_) {
        Navigator.of(context).maybePop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Item' : 'Add Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Item Name Field
              TextFormField(
                key: const Key('item_name_field'),
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Item name *',
                  hintText: 'e.g. Greek Yogurt',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Selector
              DropdownButtonFormField<PantryCategory>(
                key: const Key('item_category_field'),
                initialValue: _category,
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
                    setState(() => _category = cat);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Quantity Stepper
              Card.outlined(
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
                          Text('Quantity', style: theme.textTheme.titleMedium),
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
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '$_quantity',
                              key: const Key('quantity_value_text'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton.outlined(
                            key: const Key('quantity_increment_button'),
                            icon: const Icon(Icons.add),
                            onPressed: () => setState(() => _quantity++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expiry Date Picker Card
              Card.outlined(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Expiry date'),
                  subtitle: Text(
                    DateFormat.yMMMd().format(_expiryDate),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Change'),
                    onPressed: _selectExpiryDate,
                  ),
                  onTap: _selectExpiryDate,
                ),
              ),
              const SizedBox(height: 16),

              // Optional Barcode Field
              TextFormField(
                key: const Key('item_barcode_field'),
                controller: _barcodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Barcode (optional)',
                  hintText: 'e.g. 737628064502',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_scanner_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button with loading state
              FilledButton(
                key: const Key('save_item_button'),
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Add Item',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
