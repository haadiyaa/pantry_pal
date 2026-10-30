import 'package:equatable/equatable.dart';

import '../../domain/models/receipt_draft.dart';

enum ReceiptScanStatus {
  idle,
  pickingImage,
  recognizing,
  parsed,
  noItemsFound,
  failure,
}

class ReceiptScanState extends Equatable {
  const ReceiptScanState({
    this.status = ReceiptScanStatus.idle,
    this.draft,
    this.errorMessage,
    this.isPermanentlyDenied = false,
  });

  final ReceiptScanStatus status;
  final ReceiptDraft? draft;
  final String? errorMessage;
  final bool isPermanentlyDenied;

  bool get isLoading =>
      status == ReceiptScanStatus.pickingImage ||
      status == ReceiptScanStatus.recognizing;

  ReceiptScanState copyWith({
    ReceiptScanStatus? status,
    ReceiptDraft? Function()? draft,
    String? Function()? errorMessage,
    bool? isPermanentlyDenied,
  }) {
    return ReceiptScanState(
      status: status ?? this.status,
      draft: draft != null ? draft() : this.draft,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isPermanentlyDenied: isPermanentlyDenied ?? this.isPermanentlyDenied,
    );
  }

  @override
  List<Object?> get props => [
        status,
        draft,
        errorMessage,
        isPermanentlyDenied,
      ];
}

