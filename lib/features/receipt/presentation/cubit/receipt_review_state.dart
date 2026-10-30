import 'package:equatable/equatable.dart';

import 'receipt_review_item.dart';

enum ReceiptReviewStatus {
  initial,
  loading,
  ready,
  saving,
  saveSuccess,
  failure,
}

class ReceiptReviewState extends Equatable {
  const ReceiptReviewState({
    this.status = ReceiptReviewStatus.initial,
    this.items = const [],
    this.receiptDate,
    this.errorMessage,
    this.savedCount = 0,
  });

  final ReceiptReviewStatus status;
  final List<ReceiptReviewItem> items;
  final DateTime? receiptDate;
  final String? errorMessage;
  final int savedCount;

  int get totalCount => items.length;
  int get includedCount => items.where((i) => i.isIncluded).length;
  bool get allSelected => items.isNotEmpty && items.every((i) => i.isIncluded);
  bool get noneSelected => items.every((i) => !i.isIncluded);
  bool get isSaving => status == ReceiptReviewStatus.saving;

  ReceiptReviewState copyWith({
    ReceiptReviewStatus? status,
    List<ReceiptReviewItem>? items,
    DateTime? Function()? receiptDate,
    String? Function()? errorMessage,
    int? savedCount,
  }) {
    return ReceiptReviewState(
      status: status ?? this.status,
      items: items ?? this.items,
      receiptDate:
          receiptDate != null ? receiptDate() : this.receiptDate,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      savedCount: savedCount ?? this.savedCount,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        receiptDate,
        errorMessage,
        savedCount,
      ];
}

