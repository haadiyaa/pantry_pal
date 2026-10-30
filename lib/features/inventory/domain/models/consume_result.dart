import 'package:equatable/equatable.dart';

import 'pantry_event.dart';
import 'pantry_item.dart';

/// Details of a successful consume transaction.
/// Used to precisely reverse all database modifications during undo.
class ConsumeResult extends Equatable {
  const ConsumeResult({
    required this.item,
    required this.event,
    required this.previousQuantity,
    required this.wasRemoved,
    this.shoppingItemId,
    this.shoppingItemQuantityAdded = 0,
    this.shoppingItemWasCreated = false,
  });

  /// The pantry item as it existed prior to consumption.
  final PantryItem item;

  /// The event recorded in pantry_events.
  final PantryEvent event;

  /// The item quantity before consumption.
  final int previousQuantity;

  /// Whether the item was completely removed from the pantry (reached 0 quantity).
  final bool wasRemoved;

  /// The ID of the shopping item added or merged, if any.
  final int? shoppingItemId;

  /// The quantity added to the shopping item (1 if added, 0 if not).
  final int shoppingItemQuantityAdded;

  /// True if a new shopping item row was created, false if merged with an existing row.
  final bool shoppingItemWasCreated;

  @override
  List<Object?> get props => [
        item,
        event,
        previousQuantity,
        wasRemoved,
        shoppingItemId,
        shoppingItemQuantityAdded,
        shoppingItemWasCreated,
      ];
}

