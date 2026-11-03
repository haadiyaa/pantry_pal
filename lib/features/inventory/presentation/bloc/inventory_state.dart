part of 'inventory_bloc.dart';

enum InventoryStatus { initial, loading, success, failure }

final class InventoryState extends Equatable {
  const InventoryState({
    this.status = InventoryStatus.initial,
    this.items = const [],
    this.totalItemCount = 0,
    this.searchQuery = '',
    this.selectedCategories = const {},
    this.expiringSoonOnly = false,
    this.uiMessage,
    ConsumeResult? lastConsumeResult,
    this.errorMessage,
    // ignore: prefer_initializing_formals - parameter preserves public name for backwards compatibility.
  }) : _lastConsumeResult = lastConsumeResult;

  final InventoryStatus status;
  final List<PantryItem> items;
  final int totalItemCount;
  final String searchQuery;
  final Set<String> selectedCategories;
  final bool expiringSoonOnly;

  /// One-shot UI notification message with unique ID.
  final UiMessage<ConsumeResult>? uiMessage;

  final ConsumeResult? _lastConsumeResult;
  final String? errorMessage;

  /// Backwards-compatible getter for consume result.
  ConsumeResult? get lastConsumeResult => uiMessage?.payload ?? _lastConsumeResult;

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      selectedCategories.isNotEmpty ||
      expiringSoonOnly;

  bool get isPantryEmpty => totalItemCount == 0;

  InventoryState copyWith({
    InventoryStatus? status,
    List<PantryItem>? items,
    int? totalItemCount,
    String? searchQuery,
    Set<String>? selectedCategories,
    bool? expiringSoonOnly,
    UiMessage<ConsumeResult>? Function()? uiMessage,
    ConsumeResult? Function()? lastConsumeResult,
    String? errorMessage,
  }) {
    UiMessage<ConsumeResult>? nextUiMessage;
    ConsumeResult? nextLastConsumeResult;
    if (uiMessage != null) {
      nextUiMessage = uiMessage();
      nextLastConsumeResult = nextUiMessage?.payload;
    } else if (lastConsumeResult != null) {
      final res = lastConsumeResult();
      nextLastConsumeResult = res;
      nextUiMessage = res != null
          ? UiMessage.create(
              text: 'Updated pantry',
              type: UiMessageType.undo,
              actionLabel: 'Undo',
              payload: res,
            )
          : null;
    } else {
      nextUiMessage = this.uiMessage;
      nextLastConsumeResult = _lastConsumeResult;
    }

    return InventoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      totalItemCount: totalItemCount ?? this.totalItemCount,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      expiringSoonOnly: expiringSoonOnly ?? this.expiringSoonOnly,
      uiMessage: nextUiMessage,
      lastConsumeResult: nextLastConsumeResult,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        totalItemCount,
        searchQuery,
        selectedCategories,
        expiringSoonOnly,
        uiMessage,
        lastConsumeResult,
        errorMessage,
      ];
}
