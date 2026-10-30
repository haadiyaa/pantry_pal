import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pantry_pal/features/receipt/domain/models/draft_item.dart';
import 'package:pantry_pal/features/receipt/domain/models/receipt_bounding_box.dart';
import 'package:pantry_pal/features/receipt/domain/models/receipt_draft.dart';
import 'package:pantry_pal/features/receipt/domain/models/recognized_line.dart';
import 'package:pantry_pal/features/receipt/domain/services/image_picker_service.dart';
import 'package:pantry_pal/features/receipt/domain/services/receipt_parser.dart';
import 'package:pantry_pal/features/receipt/domain/services/text_recognizer.dart';
import 'package:pantry_pal/features/receipt/presentation/cubit/receipt_scan_cubit.dart';
import 'package:pantry_pal/features/receipt/presentation/cubit/receipt_scan_state.dart';
import 'package:permission_handler/permission_handler.dart';

class MockTextRecognizer extends Mock implements TextRecognizer {}
class MockReceiptParser extends Mock implements ReceiptParser {}
class MockImagePickerService extends Mock implements ImagePickerService {}

void main() {
  late MockTextRecognizer textRecognizer;
  late MockReceiptParser receiptParser;
  late MockImagePickerService imagePickerService;

  setUpAll(() {
    registerFallbackValue(ReceiptImageSource.camera);
  });

  setUp(() {
    textRecognizer = MockTextRecognizer();
    receiptParser = MockReceiptParser();
    imagePickerService = MockImagePickerService();
  });

  const testImagePath = '/tmp/test_receipt.jpg';
  final sampleLines = [
    const RecognizedLine(
      text: 'Amul Milk 500ml 32.00',
      boundingBox: ReceiptBoundingBox(left: 10, top: 20, width: 200, height: 20),
    ),
  ];
  const sampleDraftWithItems = ReceiptDraft(
    items: [
      DraftItem(
        name: 'Amul Milk 500ml',
        quantity: 1,
        priceInPaise: 3200,
        category: 'Dairy',
      ),
    ],
  );

  group('ReceiptScanCubit', () {
    test('initial state is idle with no draft', () {
      final cubit = ReceiptScanCubit(
        textRecognizer: textRecognizer,
        receiptParser: receiptParser,
        imagePickerService: imagePickerService,
      );

      expect(cubit.state.status, ReceiptScanStatus.idle);
      expect(cubit.state.draft, isNull);
      expect(cubit.state.isPermanentlyDenied, isFalse);
    });

    blocTest<ReceiptScanCubit, ReceiptScanState>(
      'emits failure with isPermanentlyDenied when camera permission is permanently denied',
      build: () => ReceiptScanCubit(
        textRecognizer: textRecognizer,
        receiptParser: receiptParser,
        imagePickerService: imagePickerService,
        cameraPermissionChecker: () async => PermissionStatus.permanentlyDenied,
      ),
      act: (cubit) => cubit.scanReceipt(ReceiptImageSource.camera),
      expect: () => [
        isA<ReceiptScanState>()
            .having((s) => s.status, 'status', ReceiptScanStatus.failure)
            .having((s) => s.isPermanentlyDenied, 'isPermanentlyDenied', isTrue)
            .having((s) => s.errorMessage, 'errorMessage', contains('permanently denied')),
      ],
      verify: (_) {
        verifyNever(() => imagePickerService.pickImage(any()));
      },
    );

    blocTest<ReceiptScanCubit, ReceiptScanState>(
      'emits failure when camera permission is denied (not permanently)',
      build: () => ReceiptScanCubit(
        textRecognizer: textRecognizer,
        receiptParser: receiptParser,
        imagePickerService: imagePickerService,
        cameraPermissionChecker: () async => PermissionStatus.denied,
      ),
      act: (cubit) => cubit.scanReceipt(ReceiptImageSource.camera),
      expect: () => [
        isA<ReceiptScanState>()
            .having((s) => s.status, 'status', ReceiptScanStatus.failure)
            .having((s) => s.isPermanentlyDenied, 'isPermanentlyDenied', isFalse)
            .having((s) => s.errorMessage, 'errorMessage', contains('Camera permission is required')),
      ],
    );

    blocTest<ReceiptScanCubit, ReceiptScanState>(
      'emits [pickingImage, idle] when user cancels image picker',
      build: () {
        when(() => imagePickerService.pickImage(ReceiptImageSource.gallery))
            .thenAnswer((_) async => null);
        return ReceiptScanCubit(
          textRecognizer: textRecognizer,
          receiptParser: receiptParser,
          imagePickerService: imagePickerService,
        );
      },
      act: (cubit) => cubit.scanReceipt(ReceiptImageSource.gallery),
      expect: () => [
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.pickingImage),
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.idle),
      ],
    );

    blocTest<ReceiptScanCubit, ReceiptScanState>(
      'emits [pickingImage, recognizing, parsed] when receipt is parsed with items',
      build: () {
        when(() => imagePickerService.pickImage(ReceiptImageSource.camera))
            .thenAnswer((_) async => testImagePath);
        when(() => textRecognizer.recognizeText(testImagePath))
            .thenAnswer((_) async => sampleLines);
        when(() => receiptParser.parse(sampleLines))
            .thenReturn(sampleDraftWithItems);

        return ReceiptScanCubit(
          textRecognizer: textRecognizer,
          receiptParser: receiptParser,
          imagePickerService: imagePickerService,
          cameraPermissionChecker: () async => PermissionStatus.granted,
        );
      },
      act: (cubit) => cubit.scanReceipt(ReceiptImageSource.camera),
      expect: () => [
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.pickingImage),
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.recognizing),
        isA<ReceiptScanState>()
            .having((s) => s.status, 'status', ReceiptScanStatus.parsed)
            .having((s) => s.draft?.items.length, 'draft items length', 1),
      ],
    );

    blocTest<ReceiptScanCubit, ReceiptScanState>(
      'emits [pickingImage, recognizing, noItemsFound] when parsed draft contains 0 items',
      build: () {
        when(() => imagePickerService.pickImage(ReceiptImageSource.gallery))
            .thenAnswer((_) async => testImagePath);
        when(() => textRecognizer.recognizeText(testImagePath))
            .thenAnswer((_) async => []);
        when(() => receiptParser.parse([]))
            .thenReturn(const ReceiptDraft(items: []));

        return ReceiptScanCubit(
          textRecognizer: textRecognizer,
          receiptParser: receiptParser,
          imagePickerService: imagePickerService,
        );
      },
      act: (cubit) => cubit.scanReceipt(ReceiptImageSource.gallery),
      expect: () => [
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.pickingImage),
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.recognizing),
        isA<ReceiptScanState>()
            .having((s) => s.status, 'status', ReceiptScanStatus.noItemsFound)
            .having((s) => s.draft?.items, 'items', isEmpty),
      ],
    );

    blocTest<ReceiptScanCubit, ReceiptScanState>(
      'emits [pickingImage, recognizing, failure] when recognizer throws an error',
      build: () {
        when(() => imagePickerService.pickImage(ReceiptImageSource.gallery))
            .thenAnswer((_) async => testImagePath);
        when(() => textRecognizer.recognizeText(testImagePath))
            .thenThrow(Exception('Out of memory'));

        return ReceiptScanCubit(
          textRecognizer: textRecognizer,
          receiptParser: receiptParser,
          imagePickerService: imagePickerService,
        );
      },
      act: (cubit) => cubit.scanReceipt(ReceiptImageSource.gallery),
      expect: () => [
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.pickingImage),
        isA<ReceiptScanState>().having((s) => s.status, 'status', ReceiptScanStatus.recognizing),
        isA<ReceiptScanState>()
            .having((s) => s.status, 'status', ReceiptScanStatus.failure)
            .having((s) => s.errorMessage, 'errorMessage', contains('Out of memory')),
      ],
    );

    test('reset restores initial state', () {
      final cubit = ReceiptScanCubit(
        textRecognizer: textRecognizer,
        receiptParser: receiptParser,
        imagePickerService: imagePickerService,
      );

      cubit.reset();
      expect(cubit.state.status, ReceiptScanStatus.idle);
      expect(cubit.state.draft, isNull);
    });
  });
}
