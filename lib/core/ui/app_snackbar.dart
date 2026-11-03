import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'ui_message.dart';

/// Handle returned when presenting a top notification banner, allowing
/// early programmatical dismissal if desired.
class AppSnackBarHandle {
  const AppSnackBarHandle(this.dismiss);

  /// Dismisses this top banner immediately.
  final VoidCallback dismiss;
}

/// Centralized helper for presenting top-positioned notification banners across Pantry Pal.
///
/// Direct invocations of `ScaffoldMessenger.of(context).showSnackBar(...)` or inserting
/// unmanaged [OverlayEntry] widgets elsewhere are strictly forbidden.
/// All user-facing notification banners must pass through [AppSnackBar] to ensure:
/// 1. Top banner presentation in the root overlay (below status bar & notch, above dialogs and bottom sheets).
/// 2. Immediate eviction of any prior message (strictly ONE banner active at any time, zero queueing).
/// 3. Standardized durations (4s for status messages, 6s for undo actions), paused while touched.
/// 4. Natural swipe-up to dismiss early, plus an accessible close button.
/// 5. Full accessibility via live-region semantics and high-contrast theme styling.
/// 6. Clean lifecycle cleanup and BLoC dismiss callbacks without memory leaks.
class AppSnackBar {
  const AppSnackBar._();

  /// Default duration for informative notifications without actions.
  static const Duration defaultDuration = Duration(seconds: 4);

  /// Extended duration for notifications containing interactive actions (e.g. Undo).
  static const Duration actionDuration = Duration(seconds: 6);

  /// Default margin keeping the top banner elevated below the notch and status bar.
  static const EdgeInsets defaultMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  static OverlayEntry? _currentEntry;
  static _TopBannerState? _currentState;

  /// Dismisses the currently active top notification banner immediately.
  static void hide([BuildContext? context]) {
    _dismissCurrent();
  }

  static void _dismissCurrent() {
    _currentState?.dismissImmediately();
    _currentState = null;
    if (_currentEntry != null) {
      if (_currentEntry!.mounted) {
        _currentEntry!.remove();
      }
      _currentEntry = null;
    }
  }

  /// Displays an interactive top banner with an action button (e.g. "Undo").
  ///
  /// Always evicts existing banners prior to presentation. Calls [onDismissed]
  /// when the banner times out or is swiped away.
  static AppSnackBarHandle showWithAction(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    VoidCallback? onDismissed,
    Duration duration = actionDuration,
    EdgeInsets margin = defaultMargin,
  }) {
    return _showBanner(
      context,
      message: message,
      type: UiMessageType.undo,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismissed: onDismissed,
      duration: duration,
      margin: margin,
    );
  }

  /// Displays a success top notification banner.
  static AppSnackBarHandle showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = defaultDuration,
    EdgeInsets margin = defaultMargin,
    VoidCallback? onDismissed,
  }) {
    return _showBanner(
      context,
      message: message,
      type: UiMessageType.success,
      duration: duration,
      margin: margin,
      onDismissed: onDismissed,
    );
  }

  /// Displays an error top notification banner with high-contrast error coloring.
  static AppSnackBarHandle showError(
    BuildContext context, {
    required String message,
    Duration duration = defaultDuration,
    EdgeInsets margin = defaultMargin,
    VoidCallback? onDismissed,
  }) {
    return _showBanner(
      context,
      message: message,
      type: UiMessageType.error,
      duration: duration,
      margin: margin,
      onDismissed: onDismissed,
    );
  }

  /// Displays an informative top notification banner.
  static AppSnackBarHandle showInfo(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = defaultDuration,
    EdgeInsets margin = defaultMargin,
    VoidCallback? onDismissed,
  }) {
    return _showBanner(
      context,
      message: message,
      type: UiMessageType.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      margin: margin,
      onDismissed: onDismissed,
    );
  }

  /// Dispatches a top notification banner directly from a [UiMessage].
  static AppSnackBarHandle? showUiMessage(
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

  static AppSnackBarHandle _showBanner(
    BuildContext context, {
    required String message,
    required UiMessageType type,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onDismissed,
    required Duration duration,
    required EdgeInsets margin,
  }) {
    // 1. Immediately evict any prior banner, cancelling its timer and animations
    _dismissCurrent();

    final overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (overlayContext) {
        return _TopBannerWidget(
          key: const Key('app_top_banner'),
          message: message,
          type: type,
          actionLabel: actionLabel,
          onAction: onAction,
          onDismissed: onDismissed,
          duration: duration,
          margin: margin,
          disableAnimations: disableAnimations,
          onStateCreated: (state) => _currentState = state,
          onRemove: () {
            if (_currentEntry == entry) {
              _currentEntry = null;
              _currentState = null;
            }
            if (entry.mounted) {
              entry.remove();
            }
          },
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    return AppSnackBarHandle(() {
      if (_currentEntry == entry) {
        _dismissCurrent();
      }
    });
  }
}

/// Tiny StatefulWidget whose sole purpose is to manage the lifecycle of the top
/// banner's [AnimationController], [Timer], and touch-pause stopwatch.
/// Holds zero domain or business state.
class _TopBannerWidget extends StatefulWidget {
  const _TopBannerWidget({
    super.key,
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
    this.onDismissed,
    required this.duration,
    required this.margin,
    required this.disableAnimations,
    required this.onStateCreated,
    required this.onRemove,
  });

  final String message;
  final UiMessageType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismissed;
  final Duration duration;
  final EdgeInsets margin;
  final bool disableAnimations;
  final ValueChanged<_TopBannerState> onStateCreated;
  final VoidCallback onRemove;

  @override
  State<_TopBannerWidget> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  Timer? _dismissTimer;
  final Stopwatch _stopwatch = Stopwatch();
  late int _remainingMs;
  bool _isDismissed = false;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _remainingMs = widget.duration.inMilliseconds;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    if (widget.disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }

    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Announce message to assistive technology using modern Flutter API
    SemanticsService.sendAnnouncement(
      View.of(context),
      widget.message,
      TextDirection.ltr,
    );
  }

  void _startTimer() {
    _stopwatch.reset();
    _stopwatch.start();
    _dismissTimer = Timer(
      Duration(milliseconds: _remainingMs),
      _dismissNaturally,
    );
  }

  void _pauseTimer() {
    _dismissTimer?.cancel();
    _stopwatch.stop();
    _remainingMs = (_remainingMs - _stopwatch.elapsedMilliseconds).clamp(
      500,
      widget.duration.inMilliseconds,
    );
  }

  void _resumeTimer() {
    _dismissTimer?.cancel();
    _stopwatch.reset();
    _stopwatch.start();
    _dismissTimer = Timer(
      Duration(milliseconds: _remainingMs),
      _dismissNaturally,
    );
  }

  void _dismissNaturally() {
    if (_isDismissed || !mounted) return;
    _isDismissed = true;
    _dismissTimer?.cancel();
    widget.onDismissed?.call();
    _animateOut();
  }

  void _dismissEarly() {
    if (_isDismissed || !mounted) return;
    _isDismissed = true;
    _dismissTimer?.cancel();
    widget.onDismissed?.call();
    _animateOut();
  }

  void _handleAction() {
    if (_isDismissed || !mounted) return;
    _isDismissed = true;
    _dismissTimer?.cancel();
    widget.onAction?.call();
    _animateOut();
  }

  void _animateOut() {
    if (!mounted) {
      widget.onRemove();
      return;
    }
    if (widget.disableAnimations) {
      widget.onRemove();
    } else {
      _controller.reverse().then((_) {
        widget.onRemove();
      });
    }
  }

  /// Immediately terminates animation and timer when evicted by another message.
  void dismissImmediately() {
    _isDismissed = true;
    _dismissTimer?.cancel();
    _stopwatch.stop();
    if (mounted) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _stopwatch.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color backgroundColor;
    final Color foregroundColor;
    final Color actionColor;
    final IconData icon;

    switch (widget.type) {
      case UiMessageType.error:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        actionColor = colorScheme.onError;
        icon = Icons.error_outline;
      case UiMessageType.success:
        backgroundColor = colorScheme.inverseSurface;
        foregroundColor = colorScheme.onInverseSurface;
        actionColor = colorScheme.primaryContainer;
        icon = Icons.check_circle_outline;
      case UiMessageType.undo:
        backgroundColor = colorScheme.inverseSurface;
        foregroundColor = colorScheme.onInverseSurface;
        actionColor = colorScheme.primaryContainer;
        icon = Icons.info_outline;
      case UiMessageType.info:
        backgroundColor = colorScheme.inverseSurface;
        foregroundColor = colorScheme.onInverseSurface;
        actionColor = colorScheme.primaryContainer;
        icon = Icons.info_outline;
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: widget.margin,
          child: Semantics(
            liveRegion: true,
            label: widget.message,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta != null &&
                        details.primaryDelta! < 0) {
                      setState(() {
                        _dragOffset += details.primaryDelta!;
                      });
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if (_dragOffset < -15 ||
                        (details.primaryVelocity != null &&
                            details.primaryVelocity! < -100)) {
                      _dismissEarly();
                    } else {
                      setState(() {
                        _dragOffset = 0.0;
                      });
                    }
                  },
                  child: Transform.translate(
                    offset: Offset(0, _dragOffset),
                    child: Listener(
                      onPointerDown: (_) => _pauseTimer(),
                      onPointerUp: (_) => _resumeTimer(),
                      onPointerCancel: (_) => _resumeTimer(),
                      child: Material(
                        key: const Key('app_top_banner_card'),
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        color: backgroundColor,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(icon, size: 22, color: foregroundColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (widget.actionLabel != null &&
                                  widget.onAction != null) ...[
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  child: TextButton(
                                    key: const Key('top_banner_action_button'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: actionColor,
                                      visualDensity: VisualDensity.standard,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.padded,
                                    ),
                                    onPressed: _handleAction,
                                    child: Text(
                                      widget.actionLabel!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 4),
                              IconButton(
                                key: const Key('top_banner_close_button'),
                                tooltip: 'Dismiss',
                                icon: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: foregroundColor.withValues(alpha: 0.8),
                                ),
                                onPressed: _dismissEarly,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
