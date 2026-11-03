import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ui/app_snackbar.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../shopping/presentation/cubit/shopping_settings_cubit.dart';
import '../../domain/services/user_data_service.dart';
import '../cubit/settings_cubit.dart';
import '../cubit/settings_state.dart';

/// Central Settings & About screen for Pantry Pal.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SettingsCubit(
        userDataService: context.read<UserDataService>(),
      ),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  void _showPrivacyPolicy(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '100% Local-First & Private',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Pantry Pal does not create user accounts, require logins, or upload your personal groceries, recipes, or shopping lists to remote cloud servers. All data lives on your device in a local SQLite database.',
              ),
              SizedBox(height: 14),
              Text(
                'Camera Access',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'The camera is used solely on your command to scan grocery barcodes and process supermarket receipt photos using on-device ML Kit text recognition. No photos are transmitted or saved remotely.',
              ),
              SizedBox(height: 14),
              Text(
                'Internet Usage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Internet requests are made only to fetch public nutrition/product information from Open Food Facts and public culinary recipes from TheMealDB. No tracking identifiers or usage analytics are sent.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (firstDialogContext) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your pantry items, shopping list items, and waste statistics history.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(firstDialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(firstDialogContext).pop();
              _confirmDoubleCheck(context);
            },
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  void _confirmDoubleCheck(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (secondDialogContext) => AlertDialog(
        title: const Text('Are you completely sure?'),
        content: const Text(
          'All local inventory, shopping history, and analytics will be wiped immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(secondDialogContext).pop(),
            child: const Text('Keep Data'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.of(secondDialogContext).pop();
              context.read<SettingsCubit>().clearAllData().then((_) {
                if (context.mounted) {
                  context.read<InventoryBloc>().add(const InventoryStarted());
                  AppSnackBar.showSuccess(
                    context,
                    message: 'All data cleared successfully.',
                  );
                }
              });
            },
            child: const Text('Confirm & Wipe'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocListener<SettingsCubit, SettingsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackBar.showError(
              context,
              message: state.errorMessage!,
            );
          }
        },
        child: ListView(
          children: [
            // Section 1: Preferences
            const _SectionHeader(title: 'Preferences'),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications & Reminders'),
              subtitle: const Text('Daily expiry alerts and digest schedule'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/notifications'),
            ),
            BlocBuilder<ShoppingSettingsCubit, bool>(
              builder: (context, autoAdd) {
                return SwitchListTile(
                  secondary: const Icon(Icons.shopping_bag_outlined),
                  title: const Text('Shopping List Auto-Add'),
                  subtitle: const Text(
                    'Automatically add items to shopping list when marked "Used up"',
                  ),
                  value: autoAdd,
                  onChanged: (value) {
                    context.read<ShoppingSettingsCubit>().toggle(value);
                  },
                );
              },
            ),

            const Divider(),

            // Section 2: Data & Privacy
            const _SectionHeader(title: 'Data & Privacy'),
            BlocBuilder<SettingsCubit, SettingsState>(
              builder: (context, state) {
                return ListTile(
                  leading: state.isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  title: const Text('Export Data as JSON'),
                  subtitle: const Text(
                    'Backup all pantry items, shopping list, and events',
                  ),
                  onTap: state.isExporting
                      ? null
                      : () => context.read<SettingsCubit>().exportData(),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Clear All Data',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text(
                'Permanently wipe all local inventory and history',
              ),
              onTap: () => _confirmClearData(context),
            ),

            const Divider(),

            // Section 3: About
            const _SectionHeader(title: 'About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Pantry Pal'),
              subtitle: Text('Version 1.0.0 • Local-first pantry tracker'),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              subtitle: const Text('Zero telemetry, 100% on-device storage'),
              onTap: () => _showPrivacyPolicy(context),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Open Source Licenses'),
              subtitle: const Text('Third-party software notices and licenses'),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Pantry Pal',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.kitchen, size: 48, color: Colors.green),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_outlined),
              title: const Text('Source Code & Portfolio'),
              subtitle: const Text('github.com/hadiya/pantry_pal'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final url = Uri.parse('https://github.com/hadiya/pantry_pal');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
