import 'dart:math' as math;
import 'package:equatable/equatable.dart';

/// Pure Dart geometry model representing a 2D bounding box in image coordinates.
/// Has zero Flutter framework or ML Kit dependencies.
class ReceiptBoundingBox extends Equatable {
  const ReceiptBoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory ReceiptBoundingBox.zero() => const ReceiptBoundingBox(
        left: 0,
        top: 0,
        width: 0,
        height: 0,
      );

  factory ReceiptBoundingBox.fromLTRB(
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return ReceiptBoundingBox(
      left: left,
      top: top,
      width: math.max(0, right - left),
      height: math.max(0, bottom - top),
    );
  }

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerY => top + (height / 2.0);
  double get centerX => left + (width / 2.0);

  /// Checks if two bounding boxes are on approximately the same horizontal row.
  /// Two elements are considered on the same row if their vertical centers are
  /// within half the average line height, or if their vertical overlap is >= 40%.
  bool isOnSameRow(ReceiptBoundingBox other, {double toleranceFactor = 0.6}) {
    if (height <= 0 || other.height <= 0) return false;

    final verticalOverlap = math.max(
      0.0,
      math.min(bottom, other.bottom) - math.max(top, other.top),
    );
    final minHeight = math.min(height, other.height);
    final overlapRatio = verticalOverlap / minHeight;

    if (overlapRatio >= 0.4) return true;

    final avgHeight = (height + other.height) / 2.0;
    return (centerY - other.centerY).abs() <= (avgHeight * toleranceFactor);
  }

  @override
  List<Object?> get props => [left, top, width, height];
}

