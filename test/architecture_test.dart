import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The spec requires the game logic to stay Flutter-free so it runs under plain
/// `dart test` and ports cleanly — the same discipline the JS side enforces by
/// running engine tests in a `node` environment with no `window`/`document`.
///
/// Discipline alone does not survive 37 engines, so it is checked.
void main() {
  const pureDirs = [
    'lib/engine',
    'lib/data',
    'lib/i18n',
    'lib/state',
    'lib/util',
  ];

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

  /// **`styleFrom` CANNOT COLOUR A MOULDED BUTTON, and it fails silently.**
  ///
  /// Every Elevated/Filled/Outlined button in the game wears
  /// `mouldedButtonStyle` through the theme, which paints the face in a
  /// `backgroundBuilder` and leaves the Material behind it transparent. So:
  ///
  /// * `backgroundColor:` colours the layer UNDER the face — invisible, except
  ///   that it fills the FULL button rect while the face sits 4pt inside it, so
  ///   it buries the hard bottom edge and the button reads as a flat slab.
  /// * `side:` is drawn by the Material on that same full rect, which puts a
  ///   second outline 4pt above the moulded one — a ridge along the top edge.
  ///
  /// Neither throws, neither analyses, and both have shipped: the coach card's
  /// cancels came out three-dimensional the wrong way up, every Deadline Day
  /// accept button was the theme's green whatever deal it belonged to, and the
  /// sell sheet's live Cancel wore a disabled button's ink on a disabled
  /// button's outline. The face and the edge have to go through the helper —
  /// `mouldedButtonStyle(face: ..., edge: ...)` — which is what reaches the
  /// builder.
  ///
  /// `foregroundColor:` is fine and deliberately not caught: it is the label's
  /// ink and it resolves normally.
  test('no button colours its face through styleFrom', () {
    // The three that carry a moulded style. `TextButton` is left alone by the
    // theme on purpose — it is a text link — so it may style itself freely.
    final call = RegExp(
      r'(ElevatedButton|FilledButton|OutlinedButton)\.styleFrom\(',
    );
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in call.allMatches(src)) {
        // The argument list, found by balancing brackets from the open paren —
        // a fixed window would either miss a wrapped call or run into the next.
        var depth = 0;
        var i = m.end - 1;
        for (; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        final args = src.substring(m.end, i);
        for (final bad in ['backgroundColor:', 'side:']) {
          if (args.contains(bad)) {
            final line = src.substring(0, m.start).split('\n').length;
            offenders.add('${entity.path}:$line passes $bad');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These reach for a colour `styleFrom` cannot deliver on a moulded '
          'button. Ask `mouldedButtonStyle(face:, edge:, ...)` for the face '
          'instead:\n${offenders.join('\n')}',
    );
  });

  test('and the moulded style is still the thing being defended', () {
    // Guards the test above from passing because the app stopped moulding its
    // buttons, which would make it true and pointless at the same time.
    final theme = File('lib/ui/theme/app_theme.dart').readAsStringSync();
    expect(theme, contains('elevatedButtonTheme'));
    expect(theme, contains('mouldedButtonStyle'));
    final helper = File('lib/ui/widgets/store_button.dart').readAsStringSync();
    expect(
      helper,
      contains('backgroundBuilder'),
      reason: 'the face is painted there, which is the whole reason for this',
    );
  });

}
