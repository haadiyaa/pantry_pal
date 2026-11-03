import 'package:flutter/material.dart';

import 'ui_message.dart';

/// Centralized helper for presenting floating snackbars across Pantry Pal.
///
/// Direct invocations of `ScaffoldMessenger.of(context).showSnackBar(...)` are forbidden.
/// All user-facing feedback must pass through [AppSnackBar] to ensure:
/// 1. Floating presentation ([SnackBarBehavior.floating]) with rounded corners and margins.
/// 2. Immediate eviction of stale messages via [clearSnackBars].
/// 3. Standardized durations (4s for status messages, 6s for undo actions).
/// 4. High-contrast, theme-adaptive color palettes in both light and dark modes.
/// 5. Clean dismiss notifications for BLoC state cleanup.
class AppSnackBar {
  const AppSnackBar._();

  /// Default duration for informative notifications without actions.
  static const Duration defaultDuration = Duration(seconds: 4);

  /// Extended duration for notifications containing interactive actions (e.g. Undo).
  static const Duration actionDuration = Duration(seconds: 6);

  /// Default margin keeping the floating snackbar elevated above system bars and FABs.
  static const EdgeInsets defaultMargin = EdgeInsets.fromLTRB(16, 0, 16, 24);

  /// Dismisses all currently active or queued snackbars immediately.
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Displays an interactive floating snackbar with an action button (e.g. "Undo").
  ///
  /// Always clears existing snackbars prior to presentation. Calls [onDismissed]
  /// when the snackbar times out or is swiped away.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    VoidCallback? onDismissed,
    Duration duration = actionDuration,
    EdgeInsets margin = defaultMargin,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        persist: false,
        margin: margin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: actionLabel,
          textColor: colorScheme.primaryContainer,
          onPressed: onAction,
        ),
      ),
    );

    if (onDismissed != null) {
      controller.closed.then((reason) {
        if (reason != SnackBarClosedReason.action) {
          onDismissed();
        }
      });
    }

    return controller;
  }

  /// Displays a success floating snackbar.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = defaultDuration,
    EdgeInsets margin = defaultMargin,
    VoidCallback? onDismissed,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 20,
              color: colorScheme.onInverseSurface,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        persist: false,
        margin: margin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    if (onDismissed != null) {
      controller.closed.then((_) => onDismissed());
    }

    return controller;
  }

  /// Displays an error floating snackbar with high-contrast error coloring.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showError(
    BuildContext context, {
    required String message,
    Duration duration = defaultDuration,
    EdgeInsets margin = defaultMargin,
    VoidCallback? onDismissed,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: colorScheme.onError,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onError,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: margin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    if (onDismissed != null) {
      controller.closed.then((_) => onDismissed());
    }

    return controller;
  }

  /// Displays an informative floating snackbar.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showInfo(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = defaultDuration,
    EdgeInsets margin = defaultMargin,
    VoidCallback? onDismissed,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: colorScheme.onInverseSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        persist: false,
        margin: margin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: colorScheme.primaryContainer,
                onPressed: onAction,
              )
            : null,
      ),
    );

    if (onDismissed != null) {
      controller.closed.then((reason) {
        if (reason != SnackBarClosedReason.action) {
          onDismissed();
        }
      });
    }

    return controller;
  }

  /// Dispatches a floating snackbar directly from a [UiMessage].
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUiMessage(
    BuildContext context,
    UiMessage<dynamic> message, {
    VoidCallback? onAction,
    VoidCallback? onDismissed,
    EdgeInsets margin = defaultMargin,
  }) {
    switch (message.type) {
      case UiMessageType.error:
        return showError(
          context,
          message: message.text,
          margin: margin,
          onDismissed: onDismissed,
        );
      case UiMessageType.success:
        return showSuccess(
          context,
          message: message.text,
          margin: margin,
          onDismissed: onDismissed,
        );
      case UiMessageType.undo:
        if (message.actionLabel != null && onAction != null) {
          return showWithAction(
            context,
            message: message.text,
            actionLabel: message.actionLabel!,
            onAction: onAction,
            margin: margin,
            onDismissed: onDismissed,
          );
        }
        return showInfo(
          context,
          message: message.text,
          margin: margin,
          onDismissed: onDismissed,
        );
      case UiMessageType.info:
        return showInfo(
          context,
          message: message.text,
          actionLabel: message.actionLabel,
          onAction: onAction,
          margin: margin,
          onDismissed: onDismissed,
        );
    }
  }
}
