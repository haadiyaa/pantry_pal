import 'dart:convert';
import 'dart:io';

import 'package:pantry_pal/features/receipt/domain/models/receipt_bounding_box.dart';
import 'package:pantry_pal/features/receipt/domain/models/recognized_line.dart';

/// Helper to load JSON receipt test fixtures into pure Dart [RecognizedLine] objects.
class ReceiptFixtureHelper {
  static List<RecognizedLine> loadFixture(String fixtureName) {
    // Try multiple possible relative paths depending on where test is run from
    final possiblePaths = [
      'test/fixtures/receipts/$fixtureName.json',
      '../test/fixtures/receipts/$fixtureName.json',
      'fixtures/receipts/$fixtureName.json',
    ];

    File? file;
    for (final p in possiblePaths) {
      final f = File(p);
      if (f.existsSync()) {
        file = f;
        break;
      }
    }

    if (file == null) {
      throw StateError('Fixture file not found: $fixtureName.json');
    }

    final jsonString = file.readAsStringSync();
    final jsonList = jsonDecode(jsonString) as List<dynamic>;

    return jsonList.map((entry) {
      final map = entry as Map<String, dynamic>;
      return RecognizedLine(
        text: map['text'] as String,
        boundingBox: ReceiptBoundingBox(
          left: (map['left'] as num).toDouble(),
          top: (map['top'] as num).toDouble(),
          width: (map['width'] as num).toDouble(),
          height: (map['height'] as num).toDouble(),
        ),
      );
    }).toList();
  }
}

