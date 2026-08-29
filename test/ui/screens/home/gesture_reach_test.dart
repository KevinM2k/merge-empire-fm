/// **WHERE A GESTURE ACTUALLY PUTS HIS HAND.**
///
/// A pose is written as four angles and read as a picture, and nothing in
/// between ever checked that the two agree. Three of the sixteen were putting
/// limbs inside his own skull and one was putting a hand on nothing at all —
/// found by playing, which is the expensive way:
///
///   * the WAVE raised the upper arm to -150, which sits the elbow 10.2 units
///     inside the skull and the forearm 9.6, so the whole limb was painted
///     behind his face and only the hand came out above the crown;
///   * the FIST PUMP peaked 0.96 units off the face, which at this scale is
///     touching;
///   * the BADGE KISS's one held keyframe landed 3.3 units inside the skull —
///     on his jaw, behind it — and never went near the badge;
///   * ARMS FOLDED put the two hands ten and a half units apart, and the far
///     one inside the torso, which is painted over it.
///
/// So this re-solves the chain from the rig's own constants and asks the
/// question the playthrough asked. Forward kinematics, not a golden file: if
/// the shoulder moves or the arm is relengthened — both have happened — the
/// answers move with it and a pose that stops working says so here.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/walker_figure.dart';

/// The two bones, off the three points the painter turns about.
final double _upperLength = armElbow.dy - armShoulder.dy;
final double _foreLength = armHand.dy - armElbow.dy;

/// The canvas's own rotation: positive is clockwise, and y is down.
Offset _rot(Offset v, double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a);
  final s = math.sin(a);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

/// The elbow and the hand, for one pair of angles. `foreNear` is relative to
/// the upper arm, exactly as the painter's nested `_about` applies it.
({Offset elbow, Offset hand}) _reach(double arm, double fore) {
  final elbow = armShoulder + _rot(Offset(0, _upperLength), arm);
  final hand = elbow + _rot(Offset(0, _foreLength), arm + fore);
  return (elbow: elbow, hand: hand);
}

/// How much daylight there is between a limb segment and the skull. Negative
/// means the segment is inside it — which is to say painted behind the face.
double _gap(Offset a, Offset b, double halfWidth) {
  final d = b - a;
  final len = d.dx * d.dx + d.dy * d.dy;
  final t = len == 0
      ? 0.0
      : (((skullOnScreen - a).dx * d.dx + (skullOnScreen - a).dy * d.dy) / len)
            .clamp(0.0, 1.0);
  final near = a + d * t;
  return (near - skullOnScreen).distance - skullRadius - halfWidth;
}

/// The hand's own oval, and the widths [paintLimb] draws the two bones at.
final double _handHalf = handSize.width / 2;
const double _upperHalf = 5.5;
const double _foreHalf = 3.7;

({double hand, double upper, double fore}) _clearance(double arm, double fore) {
  final r = _reach(arm, fore);
  return (
    hand: (r.hand - skullOnScreen).distance - skullRadius - _handHalf,
    upper: _gap(armShoulder, r.elbow, _upperHalf),
    fore: _gap(r.elbow, r.hand, _foreHalf),
  );
}

/// One arm through one whole play of a gesture.
Iterable<({double at, double arm, double fore})> _sweep(
  String id, {
  required bool near,
}) sync* {
  for (var i = 0; i <= 100; i++) {
    final at = i / 100;
    final pose = gesturePose(id, at);
    yield (
      at: at,
      arm: (near ? pose.armNear : pose.armFar) ??
          (near ? armNearRest : armFarRest),
      fore: (near ? pose.foreNear : pose.foreFar) ?? foreRest,
    );
  }
}

Iterable<({double at, double arm, double fore})> _nearArm(String id) =>
    _sweep(id, near: true);

void main() {
  group('NO GESTURE REACHES INSIDE HIS OWN HEAD', () {
    // The near arm is painted UNDER the head group, so a limb inside this
    // circle is a limb that is simply not on screen. The exceptions are named
    // rather than derived: a hand that belongs in front of the face gets its
    // own pass over the head, which is what [gestureHandsOverHead] is for.
    for (final gesture in gestures) {
      final id = gesture.id;
      if (!hasGesturePose(id) || gestureHandsOverHead.contains(id)) continue;
      test(id, () {
        // **Both arms.** The far one is drawn before the body rather than
        // after it, but it is still under the head group — and the robot's
        // third hold put the far hand 9.8 units inside the skull, which is a
        // limb that is not on screen whichever side of him it is on.
        for (final near in [true, false]) {
          for (final frame in _sweep(id, near: near)) {
            final c = _clearance(frame.arm, frame.fore);
            final where =
                '$id ${near ? 'near' : 'far'} at '
                '${frame.at.toStringAsFixed(2)} '
                '(arm ${frame.arm}, fore ${frame.fore})';
            expect(c.upper, greaterThan(0), reason: 'upper arm in the skull: $where');
            expect(c.fore, greaterThan(0), reason: 'forearm in the skull: $where');
            expect(c.hand, greaterThan(0), reason: 'hand in the skull: $where');
          }
        }
      });
    }
  });

  test('THE WAVE WAVES BESIDE HIS HEAD, not behind it', () {
    // The pose it replaced, kept as the thing being guarded against: -150 puts
    // the elbow deep inside the skull, and no amount of forearm fixes that.
    final was = _clearance(-150, -22);
    expect(was.upper, lessThan(-9));
    expect(was.fore, lessThan(-9));

    // And the hand still ends up high — a wave held at chest height is a
    // handshake. Level with the skull's centre or above it.
    for (final frame in _nearArm('wave')) {
      if (frame.at < 0.2 || frame.at > 0.8) continue;
      final r = _reach(frame.arm, frame.fore);
      expect(r.hand.dy, lessThan(skullOnScreen.dy + skullRadius));
      // In FRONT of him, which is the only direction that clears the head.
      expect(r.hand.dx, greaterThan(skullOnScreen.dx + skullRadius));
    }
  });

  test('AND THE FIST PUMP KEEPS ITS DISTANCE', () {
    // It was 0.96 off the face at the peak. Two units is the floor here, and
    // the pump measures well clear of it.
    var closest = double.infinity;
    var highest = double.infinity;
    for (final frame in _nearArm('fistpump')) {
      final c = _clearance(frame.arm, frame.fore);
      closest = math.min(closest, c.hand);
      highest = math.min(highest, _reach(frame.arm, frame.fore).hand.dy);
    }
    expect(closest, greaterThan(2));
    // The fist is not merely out of the way — it is HIGHER than the pose it
    // replaced, whose peak was y 43.4. Opening the elbow moves the hand
    // forward and up, which is why the clearance did not cost the gesture
    // anything.
    expect(highest, lessThan(43.4));
  });

  test('THE BADGE KISS TOUCHES THE BADGE, then the mouth', () {
    final torso = torsoPath();

    // First hold: the hand is ON him — inside the shirt's own silhouette,
    // which is the whole difference between touching the badge and waving at
    // it from 6 units out in front, where the old pose held.
    final badge = _reach(
      gesturePose('badgekiss', 0.30).armNear!,
      gesturePose('badgekiss', 0.30).foreNear!,
    );
    expect(torso.contains(badge.hand), isTrue, reason: '$badge');

    // Second hold: at the mouth. The art draws it at (71, 55.5) and the head
    // group is then moved, so on screen it is that less the set-back and lift.
    const mouth = Offset(71 - 3, 55.5 - 7);
    final kiss = _reach(
      gesturePose('badgekiss', 0.66).armNear!,
      gesturePose('badgekiss', 0.66).foreNear!,
    );
    expect((kiss.hand - mouth).distance, lessThan(4), reason: '$kiss');

    // Which only reads because the hand is drawn over the face.
    expect(gestureHandsOverHead, contains('badgekiss'));
  });

  test('AND ARMS FOLDED SHOWS TWO ARMS', () {
    final pose = gesturePose('armsfolded', 0.5);
    final near = _reach(pose.armNear!, pose.foreNear!);
    final far = _reach(pose.armFar!, pose.foreFar!);

    // Both forearms across the mid-chest rather than one on the belly and one
    // on the chest, which is what ten and a half units apart looked like.
    expect((near.hand.dy - far.hand.dy).abs(), lessThan(8));

    // **And the far hand clears the shirt.** `_WalkerPainter` draws the far arm
    // BEFORE the body, so a far hand inside the torso is painted over and the
    // fold reads as a single arm held across. The torso's front edge is the
    // line it has to get past.
    final front = torsoPath().getBounds().right;
    expect(far.hand.dx + _handHalf, greaterThan(front));

    // The near forearm still lies on top of the far one.
    expect(near.hand.dy, lessThan(far.hand.dy));
  });

  _smokeTests();

  group('THE NEAR ARM IS DRAWN OVER THE COAT', () {
    // The garment's own geometry is an opaque torso — the coat's body is one
    // path across the whole of x 47.8..69.9 — and it was painted over the arm
    // nearest the eye, so a coat or a suit simply had no near arm.
    Future<void> pump(WidgetTester tester, String outfit) => tester.pumpWidget(
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
                look: {...defaultManagerLook, 'outfit': outfit},
              ),
            ),
          ),
        ),
      ),
    );

    final coatArm = find.byKey(const ValueKey('manager-walker-coat-arm'));

    testWidgets('for the two outfits that have one', (tester) async {
      for (final outfit in ['coat', 'suit']) {
        await pump(tester, outfit);
        expect(coatArm, findsOneWidget, reason: outfit);
      }
    });

    testWidgets('and not for the ones that do not', (tester) async {
      // The playing kit draws no overlay at all, so there is nothing to be in
      // front of and a second pass would be a second arm.
      await pump(tester, 'kit');
      expect(coatArm, findsNothing);
    });
  });
}

/// **THE CIGAR SMOKES.** `managerFaces['cigar']` ships three
/// `.mgr-smoke-puff` circles at ONE point, because in the JS the class is a CSS
/// animation and the SVG only says where each puff starts. Drawn as a file that
/// is a grey disc on the end of the cigar that never moves.
void _smokeTests() {
  test('THE STATIC SMOKE GROUP IS CUT OUT OF THE ART', () {
    const svg =
        '<svg><path d="M1 1"/><g class="mgr-smoke">'
        '<circle cx="1" cy="1" r="1"/></g></svg>';
    expect(withoutStaticSmoke(svg), '<svg><path d="M1 1"/></svg>');
    // Every other drawing in the wardrobe passes through untouched.
    expect(withoutStaticSmoke('<svg><path d="M1 1"/></svg>'),
        '<svg><path d="M1 1"/></svg>');
  });

  test('and the art it is cut from is the one that has it', () {
    expect(managerFaces[cigarFace], contains('mgr-smoke'));
    expect(withoutStaticSmoke(managerFaces[cigarFace]!), isNot(contains('mgr-smoke')));
    // The ember the puffs rise from is the SVG's own lit end, not a guess.
    expect(managerFaces[cigarFace], contains('#ff7a2f'));
  });

  testWidgets('THE SMOKE LAYER IS ONLY THERE FOR THE CIGAR', (tester) async {
    Future<void> pump(String face) => tester.pumpWidget(
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
                look: {...defaultManagerLook, 'face': face},
              ),
            ),
          ),
        ),
      ),
    );

    final smoke = find.byKey(const ValueKey('manager-cigar-smoke'));
    await pump(cigarFace);
    expect(smoke, findsOneWidget);
    await pump('specs');
    expect(smoke, findsNothing);
  });
}
