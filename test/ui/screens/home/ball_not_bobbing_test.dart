/// **THE BALL IS ON THE GROUND, and the ground does not bob.**
///
/// `ManagerWalker` draws the stray ball over the top of the figure so it sits
/// in front of the near leg at his boot and in front of his chest in his hands.
/// It was drawn INSIDE the translate that carries his hip bob, his shoulder
/// sway and his shiver, so a ball lying on the grass rode all three: up and
/// down twice a stride, side to side once. Reported from the couch as the ball
/// bobbing as the scene moves.
///
/// The ground shadow already had a comment saying it must stay out of that
/// transform. This is the same rule for the ball, with a test on it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';

void main() {
  testWidgets('the ball holds its place while he bobs and sways', (
    tester,
  ) async {
    const marker = ValueKey('ball-probe');
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 170,
            child: ManagerWalker(
              kit: Color(0xFFD8E64A),
              skin: Color(0xFFE0B08A),
              hair: Color(0xFF6B4A2F),
              ballLayer: Stack(
                children: [
                  Positioned(
                    left: 68,
                    bottom: 16,
                    width: 21,
                    height: 21,
                    child: SizedBox(key: marker),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // **There has to BE a bob for this to be worth asserting.** A figure that
    // never moves would pass a "the ball does not move" test without meaning
    // anything, so the rig's own rise is checked first.
    final rises = [for (var i = 0; i < 24; i++) walkerHipRise(i / 24)];
    expect(
      rises.reduce((a, b) => a > b ? a : b) -
          rises.reduce((a, b) => a < b ? a : b),
      greaterThan(0.5),
      reason: 'the walk has no bob, so this test proves nothing',
    );

    final ys = <double>[];
    final xs = <double>[];
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final at = tester.getTopLeft(find.byKey(marker));
      ys.add(at.dy);
      xs.add(at.dx);
    }
    double spread(List<double> v) =>
        v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b);

    expect(
      spread(ys),
      lessThan(0.01),
      reason: 'the ball is riding his hips again',
    );
    expect(
      spread(xs),
      lessThan(0.01),
      reason: 'the ball is swaying with his shoulders again',
    );
  });
}
