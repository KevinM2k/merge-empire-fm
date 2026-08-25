/// The momentum shading is drawn ON the pitch, in its perspective.
///
/// It was a sibling of the stage in screen space: a flat wedge across a tilted
/// pitch, spilling over the surround — reported with a screenshot as a stray
/// lighter band across the 2D pitch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';

void main() {
  testWidgets('what goes on the grass sits inside the pitch projection', (
    tester,
  ) async {
    const key = ValueKey('on-grass');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 220,
            child: CutawayStage(
              clip: null,
              onGrass: SizedBox.expand(key: key),
            ),
          ),
        ),
      ),
    );
    final idle = find.byKey(const ValueKey('cutaway-idle'));
    expect(idle, findsOneWidget);
    // Same projection as the markings: the nearest Transform above each is the
    // same widget.
    Widget tiltOf(Finder f) => tester
        .widget(find.ancestor(of: f, matching: find.byType(Transform)).first);
    expect(identical(tiltOf(find.byKey(key)), tiltOf(idle)), isTrue);
    // And the same size as the pitch plane, so it cannot reach the surround.
    expect(tester.getSize(find.byKey(key)), tester.getSize(idle));
  });
}
