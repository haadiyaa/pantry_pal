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
    this.errorMessage,
  });

  final InventoryStatus status;
  final List<PantryItem> items;
  final int totalItemCount;
  final String searchQuery;
  final Set<String> selectedCategories;
  final bool expiringSoonOnly;
  final String? errorMessage;

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
    String? errorMessage,
  }) {
    return InventoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      totalItemCount: totalItemCount ?? this.totalItemCount,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      expiringSoonOnly: expiringSoonOnly ?? this.expiringSoonOnly,
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
        errorMessage,
      ];
}
