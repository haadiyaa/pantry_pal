import 'package:equatable/equatable.dart';

import 'shopping_batch_review_item.dart';

enum ShoppingBatchReviewStatus { initial, loading, submitting, success, failure }

class ShoppingBatchReviewState extends Equatable {
  const ShoppingBatchReviewState({
    this.status = ShoppingBatchReviewStatus.initial,
    this.items = const [],
    this.errorMessage,
  });

  final ShoppingBatchReviewStatus status;
  final List<ShoppingBatchReviewItem> items;
  final String? errorMessage;

  bool get isLoading => status == ShoppingBatchReviewStatus.loading;
  bool get isSubmitting => status == ShoppingBatchReviewStatus.submitting;
  bool get isSuccess => status == ShoppingBatchReviewStatus.success;
  bool get isFailure => status == ShoppingBatchReviewStatus.failure;

  List<ShoppingBatchReviewItem> get includedItems =>
      items.where((i) => i.isIncluded).toList();

  int get includedCount => includedItems.length;

  bool get canSubmit => includedCount > 0 && !isSubmitting;

  ShoppingBatchReviewState copyWith({
    ShoppingBatchReviewStatus? status,
    List<ShoppingBatchReviewItem>? items,
    String? errorMessage,
  }) {
    return ShoppingBatchReviewState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}

