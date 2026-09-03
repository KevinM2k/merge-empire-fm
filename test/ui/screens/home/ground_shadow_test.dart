/// The ellipse under the walker's boots and under the stray ball.
///
/// **The ball's was a `BoxShape.circle` in a 21×6 box.** A circular decoration
/// sizes itself off the box's SHORTEST side, so it drew a six-wide disc under a
/// twenty-one-wide ball — a full stop rather than a shadow, and the reason a
/// bouncing ball read as having none. The JS says
/// `radial-gradient(ellipse, …)` across the whole box for both
/// `.ps-ball-shadow` and `.ps-shadow`; `GroundShadow` is that, and this is the
/// test that it spans the box rather than the short side of it.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart'
    show GroundShadow;
import 'package:merge_empire_fc/ui/screens/home/pitch_ball.dart'
    show PitchBall, ballSize;
import 'package:merge_empire_fc/data/manager_mood.dart' show Mood;

/// The ink laid down at [x] across the middle of a [w]×[h] shadow, 0..255.
Future<int> _inkAt(WidgetTester tester, double w, double h, double x) async {
  final boundary = GlobalKey();
  await tester.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: boundary,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: SizedBox(
            width: w,
            height: h,
            child: const GroundShadow(alpha: 0.5),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // **`runAsync`, or the test hangs.** `toImage` completes on the real event
  // loop and a widget test's fake clock never turns it, so awaiting it
  // directly is a deadlock rather than a failure.
  final bytes = (await tester.runAsync(() async {
    final image = await render.toImage();
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  }))!;
  // The shadow is black over white, so the darker the pixel the more ink.
  final i = (((h / 2).floor() * w.round()) + x.floor()) * 4;
  return 255 - bytes.getUint8(i).toInt();
}

void main() {
  testWidgets('the ball shadow spans the BALL, not its own six-pixel height', (
    tester,
  ) async {
    // Two pixels in from the left edge. A circle sized off the short side would
    // sit between x 7.5 and x 13.5 and leave this corner of the box empty.
    final edge = await _inkAt(tester, ballSize, 6, 2);
    expect(edge, greaterThan(0), reason: 'the shadow is a six-wide dot again');

    // And it is still a shadow rather than a bar: darkest under the ball,
    // fading out towards the ends.
    final centre = await _inkAt(tester, ballSize, 6, ballSize / 2);
    expect(centre, greaterThan(edge));
  });

  testWidgets('and the walker shares the widget, at his own 56×8', (
    tester,
  ) async {
    final edge = await _inkAt(tester, 56, 8, 4);
    final centre = await _inkAt(tester, 56, 8, 28);
    expect(edge, greaterThan(0));
    expect(centre, greaterThan(edge));
  });

  testWidgets('and the BALL is what wears it, at its own width', (
    tester,
  ) async {
    // **A shadow nothing renders is not a shadow.** The painter above proves
    // the ellipse; this proves the stray ball reaches it — the sim starts idle
    // and draws nothing at all until a ball rolls in, so the widget has to be
    // run until one does.
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            PitchBall(
              mood: Mood.neutral,
              wind: 0,
              onCue: (_) {},
              sceneWidth: 400,
              walkerLeft: 40,
            ),
          ],
        ),
      ),
    );
    final shadow = find.byType(GroundShadow);
    for (var i = 0; i < 60 && shadow.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(shadow, findsOneWidget, reason: 'no ball ever arrived');

    // **THE ASSERTION IS OPEN GRASS, not the box's size.** The shadow was
    // `ballSize` wide and seated two units above the bottom of the ball, so
    // every pixel of it was behind the silhouette — a test that checked the
    // width alone passed on a shadow nobody could see. What matters is that at
    // the ellipse's widest row it reaches PAST the ball's disc.
    final ball = tester.widget<Positioned>(
      find.ancestor(of: find.byType(Image), matching: find.byType(Positioned)).first,
    );
    final box = tester.widget<Positioned>(
      find.ancestor(of: shadow, matching: find.byType(Positioned)).first,
    );

    final widestRow = box.bottom! + box.height! / 2;
    final discCentre = ball.bottom! + ballSize / 2;
    const r = ballSize / 2;
    final dy = (widestRow - discCentre).abs();
    final ballHalfWidth = dy >= r ? 0.0 : math.sqrt(r * r - dy * dy);

    expect(
      box.width! / 2,
      greaterThan(ballHalfWidth + 2),
      reason: 'the shadow is hiding under the ball again',
    );
    // And the two are concentric, so the ring shows on both sides equally.
    expect(box.left! + box.width! / 2, closeTo(ball.left! + r, 0.01));
  });
}
