/// The arm that swings in front of the coat.
///
/// The outfit's geometry — a coat's skirt and lapels, a suit's jacket and tie —
/// is drawn as a layer OVER the rig's painter, and the near arm is the last
/// thing that painter draws. So the garment buried it: a coat was a slab with
/// one arm swinging behind the figure and none in front of it.
///
/// The spec's own word for the slot it belongs in: "drawn over the torso, hips
/// and near thigh, under the head and the near arm, so the arm still swings in
/// front of the coat".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';

void main() {
  final arm = find.byKey(const ValueKey('manager-walker-coat-arm'));

  Future<void> pump(
    WidgetTester tester, {
    required String outfit,
    Gesture? gesture,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 170,
              child: ManagerWalker(
                kit: const Color(0xFF4CAF50),
                skin: const Color(0xFFEEBB8C),
                hair: const Color(0xFF3A2A1C),
                mood: Mood.neutral,
                walking: false,
                look: {'outfit': outfit},
                gesture: gesture == null ? null : GestureCue(gesture),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('A COAT GETS THE ARM BACK ON TOP OF IT', (tester) async {
    await pump(tester, outfit: 'coat');
    expect(arm, findsOneWidget);
    await pump(tester, outfit: 'suit');
    expect(arm, findsOneWidget);
  });

  testWidgets('and the plain kit does not pay for a second pass', (
    tester,
  ) async {
    // `kit` has no overlay at all — the whole garment is a palette swap — so
    // there is nothing for the arm to be behind and nothing to redraw it over.
    await pump(tester, outfit: 'kit');
    expect(arm, findsNothing);
  });

  testWidgets('and a hand at the face is still the LAST pass', (tester) async {
    // Both passes draw the near arm alone. Over the head is above the coat
    // anyway, so a gesture that has one must not get two of them.
    await pump(
      tester,
      outfit: 'coat',
      gesture: gestures.firstWhere((g) => g.id == 'handsonhead'),
    );
    expect(arm, findsNothing);
    expect(find.byKey(const ValueKey('manager-walker-hands')), findsOneWidget);
  });
}
