import 'package:equatable/equatable.dart';

import 'draft_item.dart';

/// Output of [ReceiptParser] containing recognized items and metadata.
/// Has zero Flutter framework or ML Kit dependencies.
class ReceiptDraft extends Equatable {
  const ReceiptDraft({
    this.items = const [],
    this.receiptDate,
    this.storeName,
  });

  final List<DraftItem> items;
  final DateTime? receiptDate;
  final String? storeName;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get itemCount => items.length;

  ReceiptDraft copyWith({
    List<DraftItem>? items,
    DateTime? Function()? receiptDate,
    String? Function()? storeName,
  }) {
    return ReceiptDraft(
      items: items ?? this.items,
      receiptDate:
          receiptDate != null ? receiptDate() : this.receiptDate,
      storeName: storeName != null ? storeName() : this.storeName,
    );
  }

  @override
  List<Object?> get props => [items, receiptDate, storeName];
}

