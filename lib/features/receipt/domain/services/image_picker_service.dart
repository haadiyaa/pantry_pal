enum ReceiptImageSource { camera, gallery }

/// Abstract interface for picking or capturing images.
/// Prevents third-party plugin types (`image_picker`) from leaking into domain/presentation.
abstract class ImagePickerService {
  /// Captures or selects an image from [source].
  /// Returns the file path string, or null if the user canceled.
  Future<String?> pickImage(ReceiptImageSource source);
}

