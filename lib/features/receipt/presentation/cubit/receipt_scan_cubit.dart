import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/services/image_picker_service.dart';
import '../../domain/services/receipt_parser.dart';
import '../../domain/services/text_recognizer.dart';
import 'receipt_scan_state.dart';

typedef CameraPermissionChecker = Future<PermissionStatus> Function();

/// Controls the lifecycle of capturing and recognizing text from receipt photos.
class ReceiptScanCubit extends Cubit<ReceiptScanState> {
  ReceiptScanCubit({
    required this.textRecognizer,
    required this.receiptParser,
    required this.imagePickerService,
    CameraPermissionChecker? cameraPermissionChecker,
  })  : _cameraPermissionChecker =
            cameraPermissionChecker ?? Permission.camera.request,
        super(const ReceiptScanState());

  final TextRecognizer textRecognizer;
  final ReceiptParser receiptParser;
  final ImagePickerService imagePickerService;
  final CameraPermissionChecker _cameraPermissionChecker;

  Future<void> scanReceipt(ReceiptImageSource source) async {
    // 1. Permission checks for camera capture
    if (source == ReceiptImageSource.camera) {
      final status = await _cameraPermissionChecker();
      if (status.isPermanentlyDenied) {
        emit(state.copyWith(
          status: ReceiptScanStatus.failure,
          errorMessage: () =>
              'Camera permission is permanently denied. Please enable it in device settings to capture receipts.',
          isPermanentlyDenied: true,
        ));
        return;
      }

      if (!status.isGranted) {
        emit(state.copyWith(
          status: ReceiptScanStatus.failure,
          errorMessage: () => 'Camera permission is required to take receipt photos.',
          isPermanentlyDenied: false,
        ));
        return;
      }
    }

    // 2. Pick / Capture image
    emit(state.copyWith(
      status: ReceiptScanStatus.pickingImage,
      errorMessage: () => null,
      isPermanentlyDenied: false,
    ));

    try {
      final imagePath = await imagePickerService.pickImage(source);
      if (imagePath == null) {
        // User canceled picker
        emit(state.copyWith(status: ReceiptScanStatus.idle));
        return;
      }

      // 3. Perform on-device OCR
      emit(state.copyWith(status: ReceiptScanStatus.recognizing));

      final lines = await textRecognizer.recognizeText(imagePath);
      final draft = receiptParser.parse(lines);

      if (draft.items.isEmpty) {
        emit(state.copyWith(
          status: ReceiptScanStatus.noItemsFound,
          draft: () => draft,
        ));
      } else {
        emit(state.copyWith(
          status: ReceiptScanStatus.parsed,
          draft: () => draft,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ReceiptScanStatus.failure,
        errorMessage: () => 'Failed to process receipt: $e',
      ));
    }
  }

  void reset() {
    emit(const ReceiptScanState());
  }
}

