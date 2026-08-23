/// A hand that belongs in front of the face.
///
/// The head and everything it wears is a stack of widgets ABOVE the rig's
/// painter — that is what lets a head tilt take the hair, the beard, the
/// glasses and the hat with it — so a hand brought to the face is painted
/// behind it. Reported as head in hands putting the hands behind the head.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';

void main() {
  test('EVERY GESTURE NAMED IS ONE THE GAME ACTUALLY HAS', () {
    // A typo here is a pose that silently never gets the second pass.
    final known = gestures.map((g) => g.id).toSet();
    for (final id in gestureHandsOverHead) {
      expect(known, contains(id), reason: id);
    }
  });

  test('and head in hands is one of them', () {
    expect(gestureHandsOverHead, contains('handsonhead'));
  });

  testWidgets('THE SECOND PASS ONLY EXISTS WHILE ONE IS PLAYING', (
    tester,
  ) async {
    final hands = find.byKey(const ValueKey('manager-walker-hands'));

    Future<void> pump(Gesture? gesture) async {
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
                  mood: Mood.crushed,
                  walking: false,
                  gesture: gesture == null ? null : GestureCue(gesture),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    // At rest his arms are by his sides; a second pass would be two of them.
    await pump(null);
    expect(hands, findsNothing);

    await pump(gestures.firstWhere((g) => g.id == 'handsonhead'));
    expect(hands, findsOneWidget);

    // And a gesture whose hand stays clear of the face gets no second pass.
    await pump(gestures.firstWhere((g) => g.id == 'handsonhips'));
    expect(hands, findsNothing);
  });
}
