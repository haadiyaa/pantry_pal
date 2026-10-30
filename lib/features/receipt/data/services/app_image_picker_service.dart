import 'package:image_picker/image_picker.dart';

import '../../domain/services/image_picker_service.dart';

/// Concrete implementation of [ImagePickerService] using the official `image_picker` plugin.
class AppImagePickerService implements ImagePickerService {
  AppImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImage(ReceiptImageSource source) async {
    final imageSource = source == ReceiptImageSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    // Downscale images to max 1920x1920 with 85% quality to optimize OCR processing speed
    // and memory consumption on low-end mobile devices without degrading text clarity.
    final pickedFile = await _picker.pickImage(
      source: imageSource,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    return pickedFile?.path;
  }
}

