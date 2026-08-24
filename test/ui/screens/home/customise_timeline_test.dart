/// **A TIMELINE for "the customise sheet is slow to open", not another
/// deferral.**
///
/// Reported three times. The first two passes each moved the grid's cost
/// somewhere else and were reported again; this file is where the third one
/// measured it. Run it and the frames print — an empty sheet of the same shape
/// for the floor, the frame the pill is tapped, then every frame of the slide.
///
/// What it found, warm:
///
/// - an empty sheet's opening frame is 18ms, so that much is the popup
///   machinery and not this sheet;
/// - the customiser's is 40ms, the extra being its header, stage and picker;
/// - the slide's own frames cost 1.5ms out of sixteen — fifteen frames of
///   headroom going to waste;
/// - and a ROW of four chips, the old fill unit, is 39ms then 16ms. Which is
///   why every placement of it was reported: a row does not fit in a frame, so
///   it dropped one wherever it went, and behind the route's animation it
///   dropped it at the moment the sheet LANDS.
///
/// A chip fits. The assertion below is the structural half of that — the
/// milliseconds are the machine's and would flake in CI, but "the grid is full
/// before the sheet has finished travelling" is the same fact and is not.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';

import 'home_screen_test.dart' show pumpHome;

/// Every chip on screen, however many axes' worth.
int _chipsBuilt() => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('customise-chip-'),
    )
    .evaluate()
    .length;

void main() {
  tearDown(resetLocale);

  testWidgets('THE GRID IS FULL BEFORE THE SHEET LANDS', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpHome(tester);

    // The floor: an empty sheet of the same shape.
    final ctx = tester.element(find.byKey(const ValueKey('dock-customise')));
    var sw = Stopwatch()..start();
    unawaited(
      showBottomSheetPopup<void>(
        ctx,
        heightFraction: 0.86,
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    // ignore: avoid_print
    print('empty sheet, opening frame: ${sw.elapsedMicroseconds / 1000}ms');
    await tester.pumpAndSettle();
    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();

    sw = Stopwatch()..start();
    await tester.tap(find.byKey(const ValueKey('dock-customise')));
    await tester.pump();
    // ignore: avoid_print
    print('customiser, opening frame: ${sw.elapsedMicroseconds / 1000}ms');

    // The route's own animation says when the sheet has stopped moving.
    final route = ModalRoute.of(
      tester.element(find.byKey(const ValueKey('manager-customiser'))),
    )!;
    var landed = 0;
    for (var i = 0; i < 24 && landed == 0; i++) {
      sw.reset();
      await tester.pump(const Duration(milliseconds: 16));
      // ignore: avoid_print
      print(
        'frame $i: ${sw.elapsedMicroseconds / 1000}ms · '
        '${_chipsBuilt()} chips',
      );
      if (route.animation!.isCompleted) landed = i;
    }
    expect(landed, greaterThan(0), reason: 'the sheet never finished opening');

    final atLanding = _chipsBuilt();
    await tester.pumpAndSettle();
    expect(
      atLanding,
      _chipsBuilt(),
      reason:
          'chips were still arriving after the sheet stopped moving — that is '
          'the judder, and it is what filling a ROW at a time caused',
    );
    expect(atLanding, greaterThan(0));
  });
}
