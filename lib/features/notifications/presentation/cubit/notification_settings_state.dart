import 'package:equatable/equatable.dart';

import '../../domain/models/notification_settings.dart';

enum NotificationPermissionStatus { initial, granted, denied, permanentlyDenied }

class NotificationSettingsState extends Equatable {
  const NotificationSettingsState({
    this.settings = const NotificationSettings(),
    this.permissionStatus = NotificationPermissionStatus.initial,
    this.isLoading = false,
    this.testNotificationSent = false,
    this.errorMessage,
  });

  final NotificationSettings settings;
  final NotificationPermissionStatus permissionStatus;
  final bool isLoading;
  final bool testNotificationSent;
  final String? errorMessage;

  NotificationSettingsState copyWith({
    NotificationSettings? settings,
    NotificationPermissionStatus? permissionStatus,
    bool? isLoading,
    bool? testNotificationSent,
    String? Function()? errorMessage,
  }) {
    return NotificationSettingsState(
      settings: settings ?? this.settings,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      isLoading: isLoading ?? this.isLoading,
      testNotificationSent: testNotificationSent ?? this.testNotificationSent,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        settings,
        permissionStatus,
        isLoading,
        testNotificationSent,
        errorMessage,
      ];
}

