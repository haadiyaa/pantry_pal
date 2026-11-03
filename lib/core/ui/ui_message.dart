import 'package:equatable/equatable.dart';

/// Semantic role for floating snackbar presentations.
enum UiMessageType {
  info,
  success,
  error,
  undo,
}

/// Immutable, one-shot UI notification model.
///
/// Driven by unique IDs so that [BlocListener]s and [BlocConsumer]s with
/// `listenWhen: (prev, curr) => prev.uiMessage?.id != curr.uiMessage?.id && curr.uiMessage != null`
/// fire exactly once per dispatched action, never replaying across widget rebuilds
/// or route restorations.
class UiMessage<T> extends Equatable {
  const UiMessage({
    required this.id,
    required this.text,
    this.type = UiMessageType.info,
    this.actionLabel,
    this.payload,
  });

  /// Factory creating a message with a globally unique ID.
  factory UiMessage.create({
    required String text,
    UiMessageType type = UiMessageType.info,
    String? actionLabel,
    T? payload,
  }) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    return UiMessage(
      id: id,
      text: text,
      type: type,
      actionLabel: actionLabel,
      payload: payload,
    );
  }

  static int _counter = 0;

  /// Unique identifier ensuring one-shot delivery.
  final String id;

  /// Human-readable message text.
  final String text;

  /// Visual and semantic role.
  final UiMessageType type;

  /// Optional action label (e.g. 'Undo', 'View list').
  final String? actionLabel;

  /// Immutable context payload captured at the exact moment of the event
  /// (e.g. the specific [ConsumeResult] or [ShoppingItem] to be restored).
  final T? payload;

  @override
  List<Object?> get props => [id, text, type, actionLabel, payload];
}

