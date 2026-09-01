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
import 'package:merge_empire_fc/data/manager_looks.dart';
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

  testWidgets('A CHIP ARRIVING DOES NOT REBUILD THE CHIPS ALREADY UP', (
    tester,
  ) async {
    // **The fill was O(n²) and the shape of the cost was backwards.** The
    // count lived on the sheet's State, so every increment rebuilt the sheet —
    // and `GridView.builder` re-runs `itemBuilder` for every live item, so the
    // frame that revealed the last chip rebuilt every chip before it. Counted
    // on the Hat axis: 171 full `ManagerWalker` rigs for eighteen chips, which
    // is 18×19/2. Celebrations 136, Hair 120. Triangular numbers are the
    // signature.
    //
    // So the point of a chip a frame was lost: the fill got more expensive the
    // further it got, and the frames measured a p50 of 15-17ms against a 16ms
    // budget all the way down.
    //
    // Asserted on widget IDENTITY rather than on milliseconds, which are the
    // machine's. A chip that was not rebuilt is the same `_Chip` instance; one
    // the grid built again is a new object however identical it looks.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('dock-customise')));

    // Part-way through the fill, with chips up and more still coming.
    var before = <Widget>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (_chipsBuilt() >= 3) break;
    }
    expect(_chipsBuilt(), greaterThanOrEqualTo(3), reason: 'the fill stalled');
    before = _chipWidgets();

    await tester.pump(const Duration(milliseconds: 16));
    final after = _chipWidgets();
    expect(
      after.length,
      greaterThan(before.length),
      reason: 'no chip arrived on that frame, so this proves nothing',
    );
    for (var i = 0; i < before.length; i++) {
      expect(
        after[i],
        same(before[i]),
        reason:
            'chip $i was rebuilt by the arrival of a later one — the fill is '
            'quadratic again',
      );
    }
    await tester.pumpAndSettle();
  });

  testWidgets('AND SELECTING ONE DOES NOT RE-RASTERISE THE REST', (
    tester,
  ) async {
    // **A chip is a PICTURE, taken once — unless the key throws it away.**
    // `_Still` is keyed on `Object.hash(axis.kind, look, pose)` and a
    // `ManagerLook` is a `Map`, which hashes by IDENTITY; `_Chip.build`
    // composes a fresh map literal every time, so the key changed on every
    // rebuild and the snapshot every chip exists to avoid was retaken on all
    // of them at once. Reported as the rig-drawing axes — hair, celebrations —
    // stuttering while the colour axes, which draw a swatch and no rig, stayed
    // smooth.
    //
    // Picking a different BUILD changes no other chip's picture: each one
    // overrides `axis.field` with its own id, so the selection is the one part
    // of the look a chip does not draw. Their snapshots must survive it.
    //
    // On element identity rather than milliseconds, for the reason the test
    // above gives: a `SnapshotWidget` whose key still matches keeps its state
    // and its picture; one whose key moved is a new element and a fresh
    // rasterisation of a full `ManagerWalker` rig.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpHome(tester);
    await tester.tap(find.byKey(const ValueKey('dock-customise')));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (_chipsBuilt() >= buildIds.length) break;
    }
    expect(_chipsBuilt(), greaterThan(2), reason: 'the grid never filled');

    // **A WARM-UP TAP FIRST, and it is not padding.** A save with no `look`
    // branch draws its chips from `defaultManagerLook`, and the first
    // selection WRITES a look — so every chip's signature legitimately moves
    // on that one tap. The question this test asks is about the taps after it.
    await tester.tap(
      find.byKey(ValueKey('customise-chip-build-${buildIds.first}')),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final before = tester.elementList(find.byType(SnapshotWidget)).toList();
    expect(before, isNotEmpty, reason: 'no chip is snapshotted at all');

    // A build the player is not already wearing, so the tap really changes
    // the save rather than being a no-op.
    final target = find.byKey(ValueKey('customise-chip-build-${buildIds.last}'));
    expect(target, findsOneWidget);
    await tester.tap(target);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final after = tester.elementList(find.byType(SnapshotWidget)).toList();
    expect(after, hasLength(before.length));
    for (var i = 0; i < before.length; i++) {
      expect(
        after[i],
        same(before[i]),
        reason:
            'chip $i threw its picture away and re-rasterised a whole rig for '
            'a selection that changed nothing it draws',
      );
    }
    // The save's own debounce, drained rather than left pending.
    await tester.pump(const Duration(seconds: 3));
  });
}

/// The chips on screen, in grid order.
List<Widget> _chipWidgets() => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('customise-chip-'),
    )
    .evaluate()
    .map((e) => e.widget)
    .toList();