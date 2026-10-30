import '../models/recognized_line.dart';

/// Abstract service for optical character recognition.
/// All Blocs depend exclusively on this interface.
/// Zero ML Kit or Flutter platform types leak through this boundary.
abstract class TextRecognizer {
  /// Processes the image at [imagePath] and returns the extracted lines.
  /// Implementations must downscale large images and execute without blocking the UI.
  Future<List<RecognizedLine>> recognizeText(String imagePath);

  /// Releases any native resources held by the recognizer.
  Future<void> dispose();
}

