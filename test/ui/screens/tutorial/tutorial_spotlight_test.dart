/// The dim, the hole, the ring and the hand.
///
/// **The hole is the feature.** A step that waits on the player has to leave
/// exactly one thing on screen pressable — the control it is teaching — and
/// block everything else. That is what these check: the scrim takes no taps,
/// the four blockers take all of them, and the gap in the middle takes none so
/// the app underneath gets it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_anchor.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_spotlight.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

/// A page with one button on it, and the spotlight over the top.
Future<int Function()> pumpOver(
  WidgetTester tester, {
  required bool aimed,
}) async {
  var taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(kitId: '#4caf50', light: false),
      home: _Page(aimed: aimed, onTap: () => taps++),
    ),
  );
  // **A second frame, because the anchor is measured off the LAID-OUT tree.**
  // The first pass builds the button; only after that does it have a render box
  // to ask. The host does the same thing through its repositioning tick.
  await tester.pump();
  return () => taps;
}

class _Page extends StatefulWidget {
  const _Page({required this.aimed, required this.onTap});

  final bool aimed;
  final VoidCallback onTap;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  Rect? _target;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.aimed) return;
      setState(() => _target = tutorialAnchorRect('the-button'));
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 100,
        top: 300,
        width: 120,
        height: 48,
        child: GestureDetector(
          key: const ValueKey('the-button'),
          onTap: widget.onTap,
          child: const ColoredBox(color: Colors.red),
        ),
      ),
      TutorialSpotlight(target: _target),
    ],
  );
}

void main() {
  testWidgets('THE HOLE LETS THE TAP THROUGH', (tester) async {
    final taps = await pumpOver(tester, aimed: true);
    await tester.tapAt(const Offset(160, 324));
    await tester.pump();
    expect(taps(), 1);
  });

  testWidgets('and everything around it is eaten', (tester) async {
    final taps = await pumpOver(tester, aimed: true);
    // Just outside the control, still inside the screen.
    await tester.tapAt(const Offset(160, 200));
    await tester.tapAt(const Offset(40, 324));
    await tester.pump();
    expect(taps(), 0);
  });

  testWidgets('WITH NOTHING TO POINT AT, NOTHING IS PRESSABLE', (tester) async {
    // The JS's own "no target" branch: a full dark overlay, no ring, no hand.
    final taps = await pumpOver(tester, aimed: false);
    await tester.tapAt(const Offset(160, 324));
    await tester.pump();
    expect(taps(), 0);
    expect(find.byKey(const ValueKey('tutorial-ring')), findsNothing);
    expect(find.byKey(const ValueKey('tutorial-hand')), findsNothing);
  });

  testWidgets('the ring and the hand sit ON the control', (tester) async {
    await pumpOver(tester, aimed: true);
    final ring = tester.getRect(find.byKey(const ValueKey('tutorial-ring')));
    // Round the control, padded — not on top of it.
    expect(ring.left, 100 - spotlightPad);
    expect(ring.top, 300 - spotlightPad);
    expect(ring.width, 120 + spotlightPad * 2);

    // The hand points UP at it from underneath, centred.
    final hand = tester.getRect(find.byKey(const ValueKey('tutorial-hand')));
    expect(hand.center.dx, closeTo(160, 0.01));
    expect(hand.top, greaterThan(ring.bottom));
  });

  group('finding the control', () {
    testWidgets('answers null for a key nothing carries', (tester) async {
      await pumpOver(tester, aimed: true);
      expect(tutorialAnchorRect('no-such-control'), isNull);
    });

    testWidgets('measures it in GLOBAL coordinates', (tester) async {
      // The overlay is laid over the whole screen, so a rect in some
      // ancestor's local space would point at the wrong place.
      await pumpOver(tester, aimed: true);
      expect(tutorialAnchorRect('the-button'), const Rect.fromLTWH(100, 300, 120, 48));
    });
  });
}
