/// **WHAT THE BUNDLE DOES NOT CONTAIN IS LOAD-BEARING.**
///
/// `lib/ui` names a weight in several hundred `TextStyle` literals, `w400`
/// through `w900`. The call from the couch was SemiBold for all of them, and
/// that is held by bundling ONE cut rather than by editing them: a family
/// resolves a weight it does not have to the nearest one it has, and with only
/// one there is nothing else to land on.
///
/// That is a claim about font matching rather than about this app's code, which
/// is exactly the kind worth pinning — if a later `pubspec.yaml` adds
/// `Barlow-Regular.ttf` or `-Bold.ttf` back, several hundred literals change
/// appearance at once and nothing else in the suite would say so.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// Width of one line set in [uiFontFamily] at [weight].
double _widthAt(FontWeight weight) => _widthAtFamily(uiFontFamily, weight);

double _widthAtFamily(String? family, FontWeight weight) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'Redlands Wanderers 12',
      style: TextStyle(fontFamily: family, fontSize: 24, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  setUpAll(() async {
    // `FontLoader` and `TextPainter` both need the test binding up.
    TestWidgetsFlutterBinding.ensureInitialized();
    // The real file, because the whole question is which cut the engine picks.
    // A widget test otherwise renders in the test font, where every weight is
    // the same width and this would pass without measuring anything.
    //
    // **Exactly what `pubspec.yaml` declares, and nothing more.** Loading the
    // other cuts here to "be thorough" would be testing a bundle the app does
    // not ship.
    final loader = FontLoader(uiFontFamily)
      ..addFont(
        File('assets/fonts/Barlow-SemiBold.ttf').readAsBytes().then(
          (bytes) => bytes.buffer.asByteData(),
        ),
      );
    await loader.load();
  });

  test('the face really did load, so the rest measures something', () {
    // The guard on the guard: with no font loaded every weight measures the
    // same in the test font, and the assertion below would hold for the wrong
    // reason entirely.
    expect(_widthAt(FontWeight.w600), greaterThan(0));
    expect(
      _widthAt(FontWeight.w600),
      isNot(closeTo(_widthAtFamily(null, FontWeight.w600), 0.01)),
      reason: 'Barlow should not measure the same as the test font',
    );
  });

  test('EVERY WEIGHT THE APP ASKS FOR RESOLVES TO SemiBold', () {
    final semiBold = _widthAt(FontWeight.w600);
    for (final weight in FontWeight.values) {
      expect(
        _widthAt(weight),
        closeTo(semiBold, 0.01),
        reason:
            '$weight is not landing on SemiBold — has another Barlow cut been '
            'added back to pubspec.yaml? Several hundred literals in lib/ui '
            'change appearance the moment one is.',
      );
    }
  });
}
