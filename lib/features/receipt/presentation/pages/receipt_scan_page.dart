import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/services/image_picker_service.dart';
import '../../domain/services/receipt_parser.dart';
import '../../domain/services/text_recognizer.dart';
import '../cubit/receipt_scan_cubit.dart';
import '../cubit/receipt_scan_state.dart';

class ReceiptScanPage extends StatelessWidget {
  const ReceiptScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReceiptScanCubit(
        textRecognizer: context.read<TextRecognizer>(),
        receiptParser: context.read<ReceiptParser>(),
        imagePickerService: context.read<ImagePickerService>(),
      ),
      child: const _ReceiptScanView(),
    );
  }
}

class _ReceiptScanView extends StatelessWidget {
  const _ReceiptScanView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<ReceiptScanCubit>();

    return BlocConsumer<ReceiptScanCubit, ReceiptScanState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == ReceiptScanStatus.parsed && state.draft != null) {
          context.push('/receipt/review', extra: state.draft);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Scan Receipt'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Illustration / Icon
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(80),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Capture Your Grocery Receipt',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan a printed store receipt to automatically import items, quantities, and prices into your pantry.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Permanent Permission Denial Card
                if (state.isPermanentlyDenied) ...[
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Camera Permission Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.errorMessage ??
                                'Camera access is permanently disabled. Please allow camera access in device settings to capture receipts.',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            key: const Key('open_camera_settings_button'),
                            onPressed: openAppSettings,
                            child: const Text('Open Device Settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Error Message Card
                if (state.status == ReceiptScanStatus.failure &&
                    !state.isPermanentlyDenied) ...[
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.errorMessage ?? 'Failed to read receipt.',
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // No Items Found State
                if (state.status == ReceiptScanStatus.noItemsFound) ...[
                  Card(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No Items Found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We could not detect grocery items or prices. Try retaking the photo with brighter lighting or add items manually.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Add Items Manually'),
                            onPressed: () => context.push('/item/new'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons or Loading Indicator
                if (state.isLoading) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          state.status == ReceiptScanStatus.pickingImage
                              ? 'Opening photo...'
                              : 'Analyzing receipt on-device...',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  FilledButton.icon(
                    key: const Key('capture_receipt_camera_button'),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Receipt Photo'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () =>
                        cubit.scanReceipt(ReceiptImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('pick_receipt_gallery_button'),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose from Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () =>
                        cubit.scanReceipt(ReceiptImageSource.gallery),
                  ),
                ],
                const SizedBox(height: 32),

                // Helpful Tips Card
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tips for best recognition:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _tipRow(
                          icon: Icons.crop_free,
                          text: 'Lay receipt flat on a dark background',
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        _tipRow(
                          icon: Icons.wb_sunny_outlined,
                          text: 'Ensure even lighting without shadows or glare',
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        _tipRow(
                          icon: Icons.zoom_in,
                          text: 'Fill the entire frame with item names and prices',
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tipRow({
    required IconData icon,
    required String text,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

