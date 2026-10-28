import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../inventory/domain/models/pantry_item.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../domain/models/product.dart';
import '../bloc/product_lookup_bloc.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  void _onProductFound(
    BuildContext context,
    Product product,
    PantryItem? existingItem,
  ) {
    if (existingItem != null) {
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (bottomSheetContext) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Item Already in Pantry',
                style: Theme.of(bottomSheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '"${product.name}" is already in your pantry with quantity x${existingItem.quantity}.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Increase Quantity (+1)'),
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  context
                      .read<ProductLookupBloc>()
                      .add(ProductLookupIncreaseQuantity(existingItem));
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add as New Entry'),
                onPressed: () {
                  Navigator.pop(bottomSheetContext);
                  _navigateToFormWithProduct(context, product);
                },
              ),
            ],
          ),
        ),
      );
    } else {
      _navigateToFormWithProduct(context, product);
    }
  }

  void _navigateToFormWithProduct(BuildContext context, Product product) {
    final prefilledItem = PantryItem(
      name: product.name,
      category: product.category,
      barcode: product.barcode,
      notes: product.brand != null && product.brand!.isNotEmpty
          ? 'Brand: ${product.brand}'
          : null,
      expiryDate: DateTime.now().add(const Duration(days: 7)),
      addedAt: DateTime.now(),
    );
    context.pushReplacement('/item/new', extra: prefilledItem);
  }

  void _onNotFound(BuildContext context, String barcode) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text(
          'Barcode $barcode was not found on Open Food Facts. Would you like to enter the details manually?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ProductLookupBloc>().add(const ProductLookupReset());
            },
            child: const Text('Scan Again'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pushReplacement(
                '/item/new',
                extra: PantryItem(
                  name: '',
                  barcode: barcode,
                  expiryDate: DateTime.now().add(const Duration(days: 7)),
                  addedAt: DateTime.now(),
                ),
              );
            },
            child: const Text('Enter Manually'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProductLookupBloc, ProductLookupState>(
      listener: (context, state) {
        if (state is ProductLookupFound) {
          _onProductFound(context, state.product, state.existingItem);
        } else if (state is ProductLookupNotFound) {
          _onNotFound(context, state.barcode);
        } else if (state is ProductLookupActionCompleted) {
          context.read<InventoryBloc>().add(const InventoryStarted());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item quantity increased!')),
          );
          context.pop();
        }
      },
      builder: (context, state) {
        final isLoading = state is ProductLookupLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Scan Barcode'),
          ),
          body: Stack(
            children: [
              _ScannerCameraView(
                isLocked: state is! ProductLookupInitial,
                onBarcodeDetected: (barcode) {
                  context
                      .read<ProductLookupBloc>()
                      .add(ProductLookupBarcodeScanned(barcode));
                },
              ),
              if (isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Looking up product details...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state is ProductLookupFailure)
                Positioned(
                  bottom: 32,
                  left: 16,
                  right: 16,
                  child: Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.barcode.isNotEmpty) ...[
                            Text(
                              'Scanned Barcode: ${state.barcode}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            state.message,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () {
                                  context
                                      .read<ProductLookupBloc>()
                                      .add(const ProductLookupReset());
                                },
                                child: const Text('Scan Again'),
                              ),
                              FilledButton.tonal(
                                onPressed: () {
                                  context.pushReplacement('/item/new');
                                },
                                child: const Text('Enter Manually'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Isolated StatefulWidget managing the lifecycle of [MobileScannerController].
class _ScannerCameraView extends StatefulWidget {
  const _ScannerCameraView({
    required this.isLocked,
    required this.onBarcodeDetected,
  });

  final bool isLocked;
  final ValueChanged<String> onBarcodeDetected;

  @override
  State<_ScannerCameraView> createState() => _ScannerCameraViewState();
}

class _ScannerCameraViewState extends State<_ScannerCameraView> {
  late final MobileScannerController _controller;
  bool _hasDetected = false;

  void _showTestBarcodeDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Simulate Barcode Scan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter a barcode number or tap a sample product to test Open Food Facts lookup on the simulator:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                hintText: 'e.g. 5449000000996',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Sample Products:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.fastfood, size: 16),
                  label: const Text('Nutella'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    widget.onBarcodeDetected('3017620422003');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.local_drink, size: 16),
                  label: const Text('Coca-Cola'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    widget.onBarcodeDetected('5449000000996');
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.cookie, size: 16),
                  label: const Text('Oreo'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    widget.onBarcodeDetected('7622210449283');
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final barcode = textController.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(dialogContext);
                widget.onBarcodeDetected(barcode);
              }
            },
            child: const Text('Lookup Product'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void didUpdateWidget(covariant _ScannerCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLocked && oldWidget.isLocked) {
      _hasDetected = false;
      _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          errorBuilder: (context, error) {
            final isPermissionDenied =
                error.errorCode == MobileScannerErrorCode.permissionDenied;

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPermissionDenied
                          ? Icons.videocam_off_outlined
                          : Icons.no_photography_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isPermissionDenied
                          ? 'Camera permission is required to scan barcodes.'
                          : 'Camera is not available on this simulator.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPermissionDenied
                          ? 'Please enable camera access in Settings.'
                          : 'The iOS Simulator has no hardware camera. You can test the scanning pipeline with a sample barcode below.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (isPermissionDenied)
                      FilledButton(
                        onPressed: openAppSettings,
                        child: const Text('Open Settings'),
                      )
                    else ...[
                      FilledButton.icon(
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Test with Barcode'),
                        onPressed: () => _showTestBarcodeDialog(context),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Enter Item Manually'),
                        onPressed: () => context.pushReplacement('/item/new'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
          onDetect: (capture) {
            if (_hasDetected || widget.isLocked) return;

            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final rawValue = barcodes.first.rawValue;
              if (rawValue != null && rawValue.trim().isNotEmpty) {
                _hasDetected = true;
                _controller.stop();
                widget.onBarcodeDetected(rawValue.trim());
              }
            }
          },
        ),
        // Scanner Overlay Controls
        Positioned(
          top: 16,
          right: 16,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final isTorchOn = state.torchState == TorchState.on;
              return IconButton.filledTonal(
                icon: Icon(isTorchOn ? Icons.flash_on : Icons.flash_off),
                onPressed: () => _controller.toggleTorch(),
                tooltip: 'Toggle flashlight',
              );
            },
          ),
        ),
        Positioned(
          bottom: 24,
          left: 32,
          right: 32,
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.edit_note),
            label: const Text('Enter Manually'),
            onPressed: () => context.pushReplacement('/item/new'),
          ),
        ),
      ],
    );
  }
}
