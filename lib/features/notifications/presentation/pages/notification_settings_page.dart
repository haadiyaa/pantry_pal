import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../cubit/notification_settings_cubit.dart';
import '../cubit/notification_settings_state.dart';
import '../../../shopping/presentation/cubit/shopping_settings_cubit.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  Future<void> _pickReminderTime(
    BuildContext context,
    int currentHour,
    int currentMinute,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
    );

    if (picked != null && context.mounted) {
      context
          .read<NotificationSettingsCubit>()
          .updateReminderTime(picked.hour, picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<NotificationSettingsCubit, NotificationSettingsState>(
      listener: (context, state) {
        if (state.testNotificationSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test notification sent! Check your device notifications.'),
              duration: Duration(seconds: 3),
            ),
          );
          context.read<NotificationSettingsCubit>().resetTestNotificationSent();
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
        final settings = state.settings;
        final cubit = context.read<NotificationSettingsCubit>();
        final isPermissionDenied =
            state.permissionStatus == NotificationPermissionStatus.denied ||
            state.permissionStatus == NotificationPermissionStatus.permanentlyDenied;

        final timeFormatted =
            '${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notification Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // Permission Warning Banner
              if (isPermissionDenied)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Notifications Disabled in System Settings',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pantry Pal needs system permission to alert you before groceries spoil.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: openAppSettings,
                        child: const Text('Open Device Settings'),
                      ),
                    ],
                  ),
                ),

              // Master Toggle
              SwitchListTile(
                title: const Text(
                  'Enable Expiry Alerts',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Receive reminders before items in your pantry expire',
                ),
                value: settings.notificationsEnabled,
                onChanged: cubit.toggleNotifications,
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
              const Divider(),

              // Reminder Time Picker
              ListTile(
                enabled: settings.notificationsEnabled,
                leading: const Icon(Icons.access_time),
                title: const Text('Reminder Time'),
                subtitle: const Text('Time of day alerts are delivered'),
                trailing: Chip(
                  label: Text(
                    timeFormatted,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                onTap: () => _pickReminderTime(
                  context,
                  settings.reminderHour,
                  settings.reminderMinute,
                ),
              ),

              // Days Before Expiry Selector
              ListTile(
                enabled: settings.notificationsEnabled,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Days Before Expiry'),
                subtitle: Text('Notify ${settings.daysBefore} days in advance + on expiry day'),
                trailing: DropdownButton<int>(
                  value: settings.daysBefore,
                  underline: const SizedBox(),
                  onChanged: settings.notificationsEnabled
                      ? (days) {
                          if (days != null) cubit.updateDaysBefore(days);
                        }
                      : null,
                  items: List.generate(7, (i) => i + 1).map((days) {
                    return DropdownMenuItem<int>(
                      value: days,
                      child: Text(days == 1 ? '1 day' : '$days days'),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),

              // Daily Digest Toggle
              SwitchListTile(
                title: const Text('Daily "Use These First" Digest'),
                subtitle: const Text(
                  'Summarize all items expiring within the next 3 days at reminder time',
                ),
                value: settings.digestEnabled,
                onChanged: settings.notificationsEnabled ? cubit.toggleDigest : null,
                secondary: const Icon(Icons.inventory_2_outlined),
              ),
              const Divider(),

              // Shopping List Integration Setting
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Shopping List',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              BlocBuilder<ShoppingSettingsCubit, bool>(
                builder: (context, addUsedUp) {
                  return SwitchListTile(
                    key: const Key('add_used_up_to_shopping_toggle'),
                    secondary: const Icon(Icons.add_shopping_cart_outlined),
                    title: const Text(
                      'Add to shopping list when I use up an item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Automatically add items to your shopping list when their quantity reaches 0',
                    ),
                    value: addUsedUp,
                    onChanged: (val) {
                      context.read<ShoppingSettingsCubit>().toggle(val);
                    },
                  );
                },
              ),
              const Divider(),

              // Test Notification Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('Schedule 1-Minute Test Reminder'),
                      onPressed: settings.notificationsEnabled
                          ? cubit.scheduleOneMinuteTestReminder
                          : null,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.notification_add_outlined),
                      label: const Text('Send Instant Test Notification'),
                      onPressed: cubit.sendTestNotification,
                    ),
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

