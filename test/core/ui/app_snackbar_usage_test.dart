import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Architecture rule: showSnackBar must ONLY be invoked inside lib/core/ui/app_snackbar.dart', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final forbiddenFiles = <String>[];
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
          forbiddenFiles.add(normalizedPath);
        }
      }
    }

    expect(
      forbiddenFiles,
      isEmpty,
      reason:
          'Direct calls to showSnackBar are forbidden! All snackbars must go through AppSnackBar. '
          'Found forbidden calls in:\n${forbiddenFiles.join('\n')}',
    );
  });
}
