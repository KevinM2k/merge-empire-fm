import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The spec requires the game logic to stay Flutter-free so it runs under plain
/// `dart test` and ports cleanly — the same discipline the JS side enforces by
/// running engine tests in a `node` environment with no `window`/`document`.
///
/// Discipline alone does not survive 37 engines, so it is checked.
void main() {
  const pureDirs = ['lib/engine', 'lib/data', 'lib/state', 'lib/util'];

  final flutterImport = RegExp(
    r'''^\s*import\s+['"]package:flutter/''',
    multiLine: true,
  );

  for (final dir in pureDirs) {
    test('$dir imports no Flutter libraries', () {
      final directory = Directory(dir);
      if (!directory.existsSync()) return;

      final offenders = <String>[];
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (flutterImport.hasMatch(entity.readAsStringSync())) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These files import package:flutter and must not — game logic has '
            'to run without a widget binding:\n${offenders.join('\n')}',
      );
    });
  }

  test('at least one pure directory exists and was actually scanned', () {
    // Guards the loop above from passing vacuously if the tree is restructured.
    final scanned = pureDirs.where((d) => Directory(d).existsSync()).toList();
    expect(scanned, isNotEmpty);
  });
}
