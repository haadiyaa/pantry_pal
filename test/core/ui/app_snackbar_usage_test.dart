import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Architecture rule: showSnackBar and notification OverlayEntry must ONLY be created inside lib/core/ui/app_snackbar.dart', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final forbiddenSnackBarFiles = <String>[];
    final forbiddenOverlayFiles = <String>[];
    const allowedPath = 'lib/core/ui/app_snackbar.dart';

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (normalizedPath == allowedPath) {
          continue;
        }

        final content = entity.readAsStringSync();
        // Check for direct invocations of showSnackBar
        if (content.contains('.showSnackBar(')) {
          forbiddenSnackBarFiles.add(normalizedPath);
        }

        // Check for ad-hoc notification OverlayEntry creations
        if (content.contains('OverlayEntry(')) {
          forbiddenOverlayFiles.add(normalizedPath);
        }
      }
    }

    expect(
      forbiddenSnackBarFiles,
      isEmpty,
      reason:
          'Direct calls to showSnackBar are forbidden! All message notifications must go through AppSnackBar. '
          'Found forbidden calls in:\n${forbiddenSnackBarFiles.join('\n')}',
    );

    expect(
      forbiddenOverlayFiles,
      isEmpty,
      reason:
          'Direct insertions of OverlayEntry are forbidden outside AppSnackBar! '
          'Found forbidden OverlayEntry in:\n${forbiddenOverlayFiles.join('\n')}',
    );
  });
}
