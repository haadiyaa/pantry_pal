import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import '../../domain/models/receipt_bounding_box.dart';
import '../../domain/models/recognized_line.dart';
import '../../domain/services/text_recognizer.dart';

/// Concrete implementation of [TextRecognizer] utilizing Google ML Kit Text Recognition v2.
/// Fully encapsulates all ML Kit types within the data layer.
class MlKitTextRecognizer implements TextRecognizer {
  MlKitTextRecognizer({
    mlkit.TextRecognizer? recognizer,
    this.deleteAfterProcessing = true,
  }) : _recognizer = recognizer ??
            mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin);

  final mlkit.TextRecognizer _recognizer;

  /// Whether to delete the temporary image file from disk once recognition finishes.
  final bool deleteAfterProcessing;

  @override
  Future<List<RecognizedLine>> recognizeText(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw ArgumentError('Image file not found at path: $imagePath');
    }

    try {
      // InputImage processes natively via background platform channel threads,
      // preventing any frame drops or UI freezing on Flutter's main isolate.
      final inputImage = mlkit.InputImage.fromFilePath(imagePath);
      final mlkit.RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);

      final lines = <RecognizedLine>[];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final rect = line.boundingBox;
          lines.add(
            RecognizedLine(
              text: line.text,
              boundingBox: ReceiptBoundingBox(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
              ),
            ),
          );
        }
      }

      return lines;
    } finally {
      // PRIVACY & STORAGE COMPLIANCE:
      // Everything runs 100% on-device. Images are never transmitted or uploaded.
      // Delete temporary image files created by image_picker once processing finishes
      // so cached receipt photos do not consume storage or linger on disk.
      if (deleteAfterProcessing) {
        try {
          if (await file.exists()) {
            await file.delete();
            debugPrint('[MlKitTextRecognizer] Cleaned up temporary image: $imagePath');
          }
        } catch (e) {
          debugPrint('[MlKitTextRecognizer] Notice: could not delete temp file: $e');
        }
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer.close();
  }
}

