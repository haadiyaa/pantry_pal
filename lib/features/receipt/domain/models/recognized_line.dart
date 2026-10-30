import 'package:equatable/equatable.dart';

import 'receipt_bounding_box.dart';

/// Pure Dart domain model representing a single recognized text line.
/// Has zero Flutter or ML Kit dependencies.
class RecognizedLine extends Equatable {
  const RecognizedLine({
    required this.text,
    required this.boundingBox,
  });

  final String text;
  final ReceiptBoundingBox boundingBox;

  double get verticalPosition => boundingBox.top;
  double get horizontalPosition => boundingBox.left;

  @override
  List<Object?> get props => [text, boundingBox];
}

