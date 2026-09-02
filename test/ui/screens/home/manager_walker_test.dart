/// The manager, walking.
///
/// He was one hardcoded man: a hand-transcribed crop haircut, a flat kit, no
/// hat and no face. `randomAvatar`, twelve hairstyles, four outfits, the hats,
/// the faces and `manager_mood.dart` were all ported with nothing reading them.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_art.dart';
import 'package:merge_empire_fc/data/manager_art.g.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/ui/screens/home/walker_figure.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

const Color _kit = Color(0xFF4CAF50);

Future<void> pumpWalker(
  WidgetTester tester, {
  ManagerLook? look,
  Mood mood = Mood.neutral,
  bool reduceMotion = true,
  double height = walkerHeight,
  bool carrying = false,
  Widget? ballLayer,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: height * walkerWidth / walkerHeight,
            height: height,
            child: ManagerWalker(
              kit: _kit,
              skin: const Color(0xFFEEBB8C),
              hair: const Color(0xFF3A2A1C),
              look: look,
              mood: mood,
              carrying: carrying,
              ballLayer: ballLayer,
            ),
          ),
        ),
      ),
    ),
  ),
);

ManagerParts partsFor(
  ManagerLook look, {
  Mood mood = Mood.neutral,
  Color kit = _kit,
}) => managerPartsFor(
  look,
  kit: kit,
  skin: const Color(0xFFEEBB8C),
  hair: const Color(0xFF3A2A1C),
  mood: mood,
);

void main() {
  /// **THE FACIAL HAIR IS ON THE FACE, and it was two units off the front of
  /// it.** Every beard in the wardrobe closes its front edge with an arc of the
  /// skull circle — deliberately, and `managerAvatar.js` says why: on a
  /// CIRCULAR head that arc is the silhouette, and a hand-drawn curve there
  /// falls inside it and leaves bare skin along the jaw.
  ///
  /// This port's head is not a circle. It narrows from the base of the nose to
  /// a chin, so below the nose the profile is around x72 while the arc is out
  /// at x74 — and a moustache hung off the front of the face between the nose
  /// and the mouth. Reported from the couch in exactly those terms.
  group('the beard is on the face', () {
    /// The front corners of the moustache, off `managerAvatar.js`'s own `TASH`:
    /// both sit exactly on the skull circle, which is the whole problem.
    const tashFront = [Offset(74, 52), Offset(73.03, 54.4)];

    test('THE ART OVERHANGS THIS HEAD, which is why it is clipped', () {
      final face = managerFaceOutline();
      for (final corner in tashFront) {
        expect(
          face.contains(corner),
          isFalse,
          reason: '$corner is inside the face — the clip has nothing to do, so '
              'either the head moved or the art did, and this test is stale',
        );
      }
      // And the skull circle it was drawn against still passes through them,
      // so the art has not moved either.
      for (final corner in tashFront) {
        expect(
          (corner - skullInArt).distance,
          closeTo(skullRadius, 0.05),
          reason: '$corner is no longer on the circle the beards use',
        );
      }
    });

    test('so the BEARD is clipped to it and nothing else is', () {
      final parts = partsFor(<String, dynamic>{
        ...defaultManagerLook,
        'beard': 'full',
        'face': 'specs',
        'hat': 'cap',
      });
      expect(parts.overHead, isNotEmpty);
      // The beard is the first layer over the head, and the only clipped one:
      // a fringe is clipped to the skull, glasses and a hat sit where the art
      // puts them, and the mouth is drawn last so a beard cannot cover it.
      expect(parts.overHead.first.clipToFace, isTrue);
      expect(
        parts.overHead.skip(1).where((l) => l.clipToFace),
        isEmpty,
        reason: 'something other than the beard is being trimmed to the face',
      );
    });

    testWidgets('and a beardless look clips nothing', (tester) async {
      final parts = partsFor(<String, dynamic>{
        ...defaultManagerLook,
        'beard': 'none',
      });
      expect(parts.overHead.where((l) => l.clipToFace), isEmpty);
    });
  });

  group('recolouring', () {
    test('swaps the slot a default colour stands for', () {
      final out = recolourManagerArt(
        '<path fill="${managerArtDefaults['hair']}"/>',
        hair: '#ff0000',
      );
      expect(out, contains('#ff0000'));
      expect(out, isNot(contains(managerArtDefaults['hair'])));
    });

    test('leaves a slot nobody named alone', () {
      const svg = '<path fill="#123456"/>';
      expect(recolourManagerArt(svg, hair: '#ff0000'), svg);
    });

    test('is case-insensitive, because the artwork writes both', () {
      final out = recolourManagerArt('<path fill="#3A2A1C"/>', hair: '#ff0000');
      expect(out, contains('#ff0000'));
    });

    test('a colour that is already the default is not rewritten', () {
      const svg = '<path fill="#3a2a1c"/>';
      expect(recolourManagerArt(svg, hair: '#3a2a1c'), svg);
    });

    test('the defaults are the generator\'s own', () {
      // If the tool ever changes a fallback, the substitution here stops finding
      // it and the figure silently keeps the old colour — so the two are pinned
      // against each other.
      final tool = File('tool/gen_manager_art.mjs').readAsStringSync();
      for (final entry in managerArtDefaults.entries) {
        expect(
          tool,
          contains(entry.value),
          reason: '${entry.key} is not the generator\'s default any more',
        );
      }
    });
  });

  group('the parts a look draws', () {
    test('hair goes on BOTH sides of the skull', () {
      // A style with a mass behind the head — flattening the two would put a
      // ponytail in front of the face.
      final parts = partsFor({...defaultManagerLook, 'style': 'pony'});
      expect(parts.behindHead, isNotEmpty);
      expect(parts.overHead, isNotEmpty);
    });

    test('a shaved head draws no hair at all rather than an empty layer', () {
      final parts = partsFor({...defaultManagerLook, 'style': 'shaved'});
      expect(parts.behindHead, isEmpty);
    });

    test('an outfit goes over the torso, a hat over the head', () {
      final parts = partsFor({
        ...defaultManagerLook,
        'outfit': 'coat',
        'hat': 'cap',
      });
      expect(parts.overTorso, isNotEmpty);
      expect(parts.overHead.length, greaterThan(1));
    });

    test('the kit colour reaches the outfit', () {
      // The suit's tie is painted with the kit, so a club in red must not have a
      // manager in the default green tie.
      final parts = partsFor({
        ...defaultManagerLook,
        'outfit': 'suit',
      }, kit: const Color(0xFFE53935));
      expect(parts.overTorso.join(), contains('#e53935'));
      expect(parts.overTorso.join(), isNot(contains('#4caf50')));
    });

    test('the mood is on his face, last of all', () {
      for (final mood in Mood.values) {
        final parts = partsFor(defaultManagerLook, mood: mood);
        expect(
          parts.overHead.last.svg,
          managerMouths[mood.name],
          reason: '${mood.name} — and nothing may cover it',
        );
      }
    });

    test('two moods do not draw the same mouth', () {
      expect(
        managerMouths[Mood.elated.name],
        isNot(managerMouths[Mood.crushed.name]),
      );
    });

    test('every part it hands back is drawable', () {
      for (final style in hairStyleIds) {
        final parts = partsFor({...defaultManagerLook, 'style': style});
        for (final svg in [
          for (final layer in parts.behindHead) layer.svg,
          ...parts.overTorso,
          for (final layer in parts.overHead) layer.svg,
        ]) {
          expect(parseSvg(svg), isNotEmpty, reason: style);
        }
      }
    });

    group('PAINT IS ON THE SKIN, hardware is on top of everything', () {
      // One axis to the player, two draw layers to the rig — `FACE_UNDER_HAIR`
      // in the JS, which the port flattened into a single slot over the lot.
      // War paint tinted the FRINGE green and swallowed the eye, which is a bad
      // recolour rather than war paint, and it is what the playtest reported.
      test('war paint, eye black and a half-face go under the hair', () {
        for (final id in ['warpaint', 'eyeblack', 'facepaint']) {
          final parts = partsFor({...defaultManagerLook, 'face': id});
          expect(parts.onSkin, hasLength(1), reason: '$id is not on the skin');
          expect(
            parts.overHead.map((l) => l.svg),
            isNot(contains(parts.onSkin.single.svg)),
            reason: '$id is drawn twice',
          );
        }
      });

      test('and glasses, a cigar and a whistle go over it', () {
        // Anything not named as paint is hardware, so a new item defaults to
        // the layer a haircut cannot hide.
        for (final id in ['specs', 'shades', 'aviators', 'cigar', 'whistle']) {
          final parts = partsFor({...defaultManagerLook, 'face': id});
          expect(parts.onSkin, isEmpty, reason: '$id is not paint');
          expect(
            parts.overHead.map((l) => l.svg),
            // **Less its static smoke**, which only the cigar has: three
            // `.mgr-smoke-puff` circles stacked on one point, because in the JS
            // that class is an animation and the file only says where each one
            // starts. Drawn as written it is a grey disc on the lit end that
            // never moves, so it is cut here and animated over the head — see
            // `_CigarSmoke`. Every other drawing passes through unchanged.
            contains(withoutStaticSmoke(managerFaces[id]!)),
            reason: '$id never reaches the face',
          );
        }
      });

      test('and a bare face draws neither', () {
        final parts = partsFor({...defaultManagerLook, 'face': 'none'});
        expect(parts.onSkin, isEmpty);
      });

      test('THE FRINGE IS ITS OWN LAYER, between the paint and the eye', () {
        // Which is the whole reason the split works: the JS's stack is skull,
        // paint, front hair, features — and the port drew the head in one pass,
        // so there was no depth for paint to go to.
        final parts = partsFor({...defaultManagerLook, 'style': 'crop'});
        expect(parts.overHair, hasLength(1));
        final (_, front) = managerHair['crop']!;
        expect(parts.overHair.single.svg, contains('path'));
        expect(front, isNotEmpty);
      });
    });

    test('and only the HAIR is ever clipped by a hat', () {
      // The hat itself must not be clipped by its own brow, and neither must the
      // beard, the face or the mouth. Two layers carry the clip and they are the
      // two halves of the hair.
      final parts = partsFor({
        ...defaultManagerLook,
        'style': 'mohawk',
        'hat': 'cap',
      });
      final clipped = [
        ...parts.behindHead,
        ...parts.onSkin,
        ...parts.overHair,
        ...parts.overHead,
      ].where((l) => l.hideAbove != null).toList();
      // A mohawk has no back layer, so one here rather than two — which is the
      // point: what gets the clip is whichever hair layers EXIST.
      expect(clipped, isNotEmpty);
      final (back, front) = managerHair['mohawk']!;
      for (final layer in clipped) {
        expect(
          [back, front].any((h) => h.isNotEmpty && layer.svg.contains('path')),
          isTrue,
          reason: 'something that is not hair was clipped',
        );
        expect(layer.svg, isNot(equals(managerHats['cap'])));
      }
    });
  });

  group('the figure', () {
    testWidgets('draws the rig and the look together', (tester) async {
      await pumpWalker(tester);
      expect(find.byKey(const ValueKey('manager-walker')), findsOneWidget);
      expect(find.byType(SvgArt), findsWidgets);
    });

    testWidgets('a look with a hat draws more than one without', (
      tester,
    ) async {
      // A FIXED look, varying only the hat. `defaultManagerLook` is generated at
      // random, so reading it twice compared two different men and the test
      // passed or failed on whether the second one happened to be wearing more.
      const base = <String, dynamic>{
        'build': 'athletic',
        'outfit': 'tracksuit',
        'style': 'crop',
        'hair': '#3a2a1c',
        'skin': '#eebb8c',
        'beard': 'stubble',
        'face': 'none',
        'neck': 'none',
      };
      await pumpWalker(tester, look: {...base, 'hat': 'none'});
      final bare = tester.widgetList<SvgArt>(find.byType(SvgArt)).length;

      await pumpWalker(tester, look: {...base, 'hat': 'crown'});
      expect(
        tester.widgetList<SvgArt>(find.byType(SvgArt)).length,
        greaterThan(bare),
      );
    });

    testWidgets('reduce-motion stops the walk, not the manager', (
      tester,
    ) async {
      await pumpWalker(tester);
      expect(find.byKey(const ValueKey('manager-walker')), findsOneWidget);
      // Nothing pending: a looping clock would never let a test settle.
      await tester.pumpAndSettle();
    });

    testWidgets('and he walks when nothing is stopping him', (tester) async {
      await pumpWalker(tester, reduceMotion: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('manager-walker')), findsOneWidget);
      // Leave him mid-stride: the clock is a repeating controller and the test
      // binding tears it down with the tree.
    });
  });

  group('the walk is the JS\'s own', () {
    // **The port solved this rig for a while and it was measurably better and
    // visibly worse.** Inverse kinematics off the foot's path gives a planted
    // foot travelling at exactly the ground's rate — no skate, no float — and it
    // takes the longest step the legs allow, so he lunged, and it kept a 40-degree
    // bend in the leg he was standing on. The JS's four keyframe tracks are what
    // looks like walking, so they are what runs; these pin them, and they pin the
    // two flaws that come with them so nobody "fixes" the walk back.

    test('the tracks are the values in league-scene.css', () {
      // psvThighN: -31 → 25 → -31. psvShinN: 6 → 4 → 13 → 60 → 6.
      expect(walkerThighAngle(0), closeTo(-31, 1e-9));
      expect(walkerThighAngle(0.5), closeTo(25, 1e-9));
      expect(walkerShinAngle(0), closeTo(6, 1e-9));
      expect(walkerShinAngle(0.25), closeTo(4, 1e-9));
      expect(walkerShinAngle(0.5), closeTo(13, 1e-9));
      expect(walkerShinAngle(0.75), closeTo(60, 1e-9));
    });

    test('and the far leg is the same tracks, half a cycle on', () {
      for (var i = 0; i <= 20; i++) {
        final t = i / 20;
        expect(
          walkerThighAngle(t, near: false),
          closeTo(walkerThighAngle((t + 0.5) % 1), 1e-9),
        );
        expect(
          walkerShinAngle(t, near: false),
          closeTo(walkerShinAngle((t + 0.5) % 1), 1e-9),
        );
      }
    });

    test('THE PLANTED LEG IS STRAIGHT, which is why it reads as a walk', () {
      // This is the difference the eye actually picks up. Through the whole
      // stance the knee is inside 15 degrees — a straight leg to stand on. The
      // solved version bent it 40 degrees just after heel strike, and a manager
      // who crouches through every stance looks wrong however true his foot is.
      for (var i = 0; i <= 20; i++) {
        final t = 0.5 * i / 20;
        expect(
          walkerShinAngle(t),
          lessThan(15),
          reason: 'crouching on it at t=$t',
        );
      }
    });

    test('and it folds hard to swing through', () {
      // 60 degrees at three quarters of the cycle. That is where a walk's knee
      // flexion lives, and it is what gets the foot clear of the grass.
      expect(walkerShinAngle(0.75), greaterThan(50));
      expect(walkerAnkle(0.75).y, lessThan(walkerAnkle(0.25).y - 8));
    });

    test('the path closes, so the loop cannot jolt', () {
      expect(walkerAnkle(0).x, closeTo(walkerAnkle(0.999999).x, 1e-3));
      expect(walkerAnkle(0).y, closeTo(walkerAnkle(0.999999).y, 1e-3));
    });

    test('the stride is the mean the ground is timed off', () {
      expect(
        walkerStrideArtUnits,
        closeTo(walkerAnkle(0).x - walkerAnkle(0.5).x, 1e-9),
      );
      expect(walkerStrideArtUnits, greaterThan(0));
    });

    test(
      'and the footline is the lowest his sole reaches, not a typed number',
      () {
        var lowest = double.negativeInfinity;
        for (var i = 0; i < 360; i++) {
          final t = i / 360;
          final sole =
              math.max(walkerBootSoleY(t), walkerBootSoleY((t + 0.5) % 1)) -
              walkerHipRise(t);
          if (sole > lowest) lowest = sole;
        }
        expect(walkerFootline, closeTo(lowest, 0.05));
      },
    );

    group('the two flaws it comes with, measured and ACCEPTED', () {
      // Written down rather than left to be rediscovered. Both are the price of
      // the JS's poses, and both were the reason the port replaced them once.

      test('the planted foot does NOT travel at a constant rate', () {
        final steps = [
          for (var i = 1; i <= 20; i++)
            walkerFootX(0.5 * i / 20) - walkerFootX(0.5 * (i - 1) / 20),
        ];
        final spread = steps.reduce(math.max) - steps.reduce(math.min);
        // ~5.6 units between the slowest and fastest quarter of the stance. The
        // ground runs at one speed, so that difference is a skate.
        expect(spread, greaterThan(1));
        expect(spread, lessThan(8), reason: 'if this grows, something moved');
      });

      test('and the sole does not hold one height', () {
        final heights = [
          for (var i = 0; i <= 20; i++)
            walkerBootSoleY(0.5 * i / 20) - walkerHipRise(0.5 * i / 20),
        ];
        final float = heights.reduce(math.max) - heights.reduce(math.min);
        // ~5.2 units of it. Deriving the bob from the supporting foot removes it
        // completely and costs a 7-unit hip correction against a 4-unit bob,
        // which reads as bouncing — so the float stays and the hips stay smooth.
        expect(float, greaterThan(1));
        expect(float, lessThan(7), reason: 'if this grows, something moved');
      });
    });
  });

  group('the poses land where they are aiming', () {
    /// Forward kinematics on the arm, in the art's own space: shoulder (56, 62),
    /// elbow 19 below it, hand 19.6 past that.
    ({Offset elbow, Offset hand}) arm(double armDeg, double foreDeg) {
      const shoulder = Offset(56, 62);
      const upper = 19.0, fore = 19.6;
      final a = armDeg * math.pi / 180;
      final elbow = Offset(
        shoulder.dx - upper * math.sin(a),
        shoulder.dy + upper * math.cos(a),
      );
      final w = (armDeg + foreDeg) * math.pi / 180;
      return (
        elbow: elbow,
        hand: Offset(
          elbow.dx - fore * math.sin(w),
          elbow.dy + fore * math.cos(w),
        ),
      );
    }

    test('HANDS ON HIPS puts the hand on the hip', () {
      // The JS's own 44 / -106 do that on the JS's arm and not on this one: they
      // land the elbow at x 42.8, five units outside a back that stops at 47.9,
      // and the hand at (60, 85) — the middle of his belly. The pose is a place a
      // hand goes, so this checks the place.
      final pose = gesturePose('handsonhips', 0.5, gestureMs: 2400);
      final near = arm(pose.armNear!, pose.foreNear!);
      expect(near.hand.dx, closeTo(65, 1.5), reason: 'not on the hip');
      expect(near.hand.dy, closeTo(89, 1.5));
      // And the elbow stays within the silhouette rather than jutting out behind.
      expect(
        near.elbow.dx,
        greaterThan(46),
        reason: 'the elbow is outside his back',
      );
    });

    /// **TOUCH THE BADGE, THEN KISS THE HAND**, asked for in those words. The
    /// JS's own angles do neither: `arm -30, fore -118` holds the hand six
    /// units clear of the shirt and `arm -52, fore -146` puts it in the middle
    /// of his face rather than on his mouth, so the gesture was a man patting
    /// the air twice.
    test('KISS THE BADGE goes to the chest, and then to the mouth', () {
      final touch = gesturePose('badgekiss', 0.3, gestureMs: 1800);
      final onBadge = arm(touch.armNear!, touch.foreNear!);
      // The front of the chest at badge height. The torso stops around x 69.
      expect(onBadge.hand.dx, closeTo(68, 2), reason: 'not on the shirt');
      expect(onBadge.hand.dy, closeTo(69.5, 2.5));

      final kiss = gesturePose('badgekiss', 0.7, gestureMs: 1800);
      final atMouth = arm(kiss.armNear!, kiss.foreNear!);
      // The blow-kiss's own hold, which the spec annotates as on the mouth.
      expect(atMouth.hand.dx, closeTo(73, 2));
      expect(atMouth.hand.dy, closeTo(52, 2.5));
      expect(
        atMouth.hand.dy,
        lessThan(onBadge.hand.dy),
        reason: 'the kiss has to come after the touch, not before it',
      );

      // And it does not go back to the chest: the kiss ends the gesture.
      final end = gesturePose('badgekiss', 1, gestureMs: 1800);
      expect(end.armNear, closeTo(armNearRest, 0.01));
    });

    /// A hand at the mouth is in front of the face, and the head is a stack of
    /// widgets ABOVE the rig — so without this the kiss was painted behind him.
    test('and the kiss is drawn in front of the face', () {
      expect(gestureHandsOverHead, contains('badgekiss'));
    });

    /// **THE WAVE IS THE ELBOW, not the hand.** Its hand clears the skull by
    /// ten units, which is why it was left out; its elbow lands inside the
    /// head. Any raised near arm does, in a rig whose shoulder is six units
    /// behind the skull's centre.
    test('A WAVE PUTS ITS ELBOW THROUGH HIS HEAD, so it is drawn in front', () {
      final pose = gesturePose('wave', 0.5, gestureMs: 1800);
      final near = arm(pose.armNear!, pose.foreNear!);
      const skull = Offset(62, 48.5);
      expect(
        (near.elbow - skull).distance,
        lessThan(12.5),
        reason: 'if the elbow has moved clear, the second pass can go',
      );
      expect(near.hand.dy, lessThan(skull.dy - 12.5));
      expect(gestureHandsOverHead, contains('wave'));
    });

    test('POINTING shows the finger', () {
      // A point with no finger is a fist held out at the pitch.
      expect(gesturePose('point', 0.5, gestureMs: 1700).finger, 1);
      expect(gesturePose('fingerwag', 0.5, gestureMs: 1900).finger, 1);
      expect(gesturePose('shush', 0.5, gestureMs: 1900).finger, 1);
    });

    test('and nothing else does', () {
      // It is hidden the rest of the time: at this size a permanent finger makes
      // the hand read as a lumpy mitten.
      for (final id in const ['handsonhips', 'applaud', 'fistpump', 'bow']) {
        expect(gesturePose(id, 0.5, gestureMs: 2000).finger, 0, reason: id);
      }
      expect(gesturePose('point', 0, gestureMs: 1700).finger, 0);
    });

    test('CHECK WATCH brings the wrist up to where he can read it', () {
      final pose = gesturePose('checkwatch', 0.5, gestureMs: 1800);
      final near = arm(pose.armNear!, pose.foreNear!);
      // The skull sits at (62, 48.5) once the head group is lifted 7, so the face
      // is around y 42. The wrist has to get near it or he is reading his knee.
      expect(near.hand.dy, lessThan(70), reason: 'the watch never came up');
      // And he looks down at it rather than staring ahead.
      expect(pose.head, greaterThan(5));
    });
  });

  group('the head, mood and gesture together', () {
    test('carries the mood: up when it is going well, down when it is not', () {
      expect(moodHeadTilt(Mood.elated), lessThan(0));
      expect(moodHeadTilt(Mood.neutral), 0);
      expect(moodHeadTilt(Mood.crushed), greaterThan(6));
      // **AND THE UP END IS SHALLOW.** Seven degrees of chin-up read as a man
      // addressing the stand rather than watching a match, and elated and
      // pleased are the two moods the dugout cam spends its life in.
      expect(moodHeadTilt(Mood.elated), greaterThan(-4));

      final ladder = Mood.values.map(moodHeadTilt).toList();
      for (var i = 1; i < ladder.length; i++) {
        expect(
          ladder[i],
          greaterThan(ladder[i - 1]),
          reason: '${Mood.values[i]}',
        );
      }
    });

    test('a LIFT only ever brings him up to level, never past it', () {
      // Adding the two blindly had a manager who was already looking straight
      // ahead raise his chin FURTHER to point at something — addressing the sky.
      double lifted(Mood m) {
        final base = moodHeadTilt(m);
        const gesture = -9.0; // `_chinUp`
        return gesture >= 0
            ? base + gesture
            : math.max(base + gesture, math.min(base, 0));
      }

      expect(
        lifted(Mood.crushed),
        closeTo(3, 0.01),
        reason: 'lifted, not level',
      );
      expect(lifted(Mood.neutral), 0, reason: 'he was already looking ahead');
      expect(
        lifted(Mood.elated),
        moodHeadTilt(Mood.elated),
        reason: 'a raised head must not raise further',
      );
    });

    test('but a gesture that looks DOWN adds to however he was carrying it', () {
      // A beaten manager checking his watch looks further down than a cheerful
      // one, and that is right.
      final watch = gesturePose('checkwatch', 0.5, gestureMs: 1800).head!;
      expect(watch, greaterThan(0));
      expect(
        moodHeadTilt(Mood.crushed) + watch,
        greaterThan(moodHeadTilt(Mood.elated) + watch),
      );
    });
  });

  group('his BUILD', () {
    test('six choices are six shapes, not one', () {
      // The axis was in the customiser, the wardrobe, the randomiser and the
      // save, and produced one figure: `buildScales`, `buildArmScale` and
      // `buildOverlay` had no port at all, and the renderer carried a `build`
      // parameter nothing ever passed.
      final widths = <String, double>{};
      for (final id in buildIds) {
        final b = buildScales(id);
        widths[id] = torsoPath(build: b.torso).getBounds().width;
      }
      expect(
        widths.values.toSet(),
        hasLength(buildIds.length),
        reason: 'two builds draw the same torso: $widths',
      );
      expect(widths['lean'], lessThan(widths['regular']!));
      expect(widths['broad'], greaterThan(widths['regular']!));
    });

    test('an unknown build is a man, not a crash', () {
      // A save from a future build still has to draw someone.
      expect(buildScales('nonesuch'), buildScales('regular'));
      expect(buildScales(null), buildScales('regular'));
    });

    test('ATHLETIC puts its muscle in the ARMS, not the legs', () {
      // Shoulder width is not legible on a figure drawn in profile and depth
      // is, which is the JS's own reason — and it is also what sells the arms
      // as the thing that changed.
      final athletic = buildScales('athletic');
      expect(athletic.arm, greaterThan(athletic.limb));
      expect(athletic.limb, closeTo(1, 0.1));
      // And nobody else separates the two.
      for (final id in buildIds.where((i) => i != 'athletic')) {
        final b = buildScales(id);
        expect(b.arm, b.limb, reason: '$id splits arms from legs');
      }
    });

    test('and the two bulges are in different halves of the torso', () {
      // The torso spans y 59 to 93, midpoint 76: a bust goes in the UPPER half
      // and a gut in the LOWER, and the two must never be confusable.
      expect(buildScales('curvy').bulge!.cy, lessThan(76));
      expect(buildScales('belly').bulge!.cy, greaterThan(76));
      // Every other build is scale-only.
      for (final id in buildIds.where((i) => i != 'curvy' && i != 'belly')) {
        expect(buildScales(id).bulge, isNull, reason: id);
      }
    });

    test('AND A BULGE HAS TO BREAK THE SILHOUETTE', () {
      // **The figure is seen side-on, so a build is its OUTLINE.** The gut
      // reached x68 and the shirt's own front edge is 69.9, so the whole of it
      // was inside the body — a slightly lighter ellipse on a green shirt.
      // Reported from the couch as the belly build not looking fat in the
      // belly. `curvy` always read, and that is the only reason why.
      for (final id in ['belly', 'curvy']) {
        final bulge = buildScales(id).bulge!;
        expect(
          bulge.cx + bulge.rx,
          greaterThan(bellyFront),
          reason: '$id is drawn entirely inside the shirt',
        );
      }
      // And the gut hangs to the waistband — the shirt hem is at y93. One that
      // stops above it reads as a barrel rather than a belly.
      final gut = buildScales('belly').bulge!;
      expect(gut.cy + gut.ry, greaterThanOrEqualTo(92));
    });

    test('and the HIP stays near 1', () {
      // The shorts are already about twice the width of the leg beneath them
      // and that flare is intended, so even 1.16 pushes the block out in front
      // of and behind the legs and reads as a slab. `broad` predates the rule.
      for (final id in buildIds.where((i) => i != 'broad')) {
        expect(buildScales(id).hip, lessThanOrEqualTo(1.05), reason: id);
      }
    });
  });

  group('what he is WEARING', () {
    test('AN OUTFIT IS MOSTLY A PALETTE, and the port had none', () {
      // The JS paints every garment from a semantic variable and swaps the
      // palette per outfit, keeping geometry only for a coat's skirt and a
      // suit's lapels. Those two are generated art and drew fine; the
      // tracksuit's entire existence is the palette, so all that reached the
      // screen was its collar swoosh — a curve across his throat, reported
      // exactly as "something like a necklace".
      for (final id in outfitIds) {
        expect(
          outfitPalettes,
          contains(id),
          reason: '$id has no palette, so it is a collar line and nothing else',
        );
      }
    });

    test('the KIT is the zero point: bare arms, bare shins', () {
      final kit = outfitPalette('kit');
      expect(kit.fore, isNull);
      expect(kit.shin, isNull);
      expect(kit.legStripe, isNull);
    });

    test('and every other outfit COVERS him', () {
      for (final id in outfitIds.where((i) => i != 'kit')) {
        final o = outfitPalette(id);
        expect(o.shin, isNotNull, reason: '$id leaves his shins bare');
        expect(
          o.fore != null || outfitSleevesAreKit(id),
          isTrue,
          reason: '$id leaves his forearms bare',
        );
      }
    });

    test('THE TRACKSUIT is the one that keeps the club on his back', () {
      // Which is why its sleeve is club-coloured CLOTH rather than a fixed
      // colour: on a striped kit the stripes run down the whole arm instead of
      // stopping at the shoulder. And it is the only one with a leg stripe —
      // the mark that tells it from plain dark trousers.
      expect(outfitSleevesAreKit('tracksuit'), isTrue);
      expect(outfitPalette('tracksuit').legStripe, isNotNull);
      for (final id in outfitIds.where((i) => i != 'tracksuit')) {
        expect(outfitSleevesAreKit(id), isFalse, reason: id);
        expect(outfitPalette(id).legStripe, isNull, reason: id);
      }
      // White trainers, not black boots.
      expect(
        outfitPalette('tracksuit').boot.computeLuminance(),
        greaterThan(outfitPalette('kit').boot.computeLuminance()),
      );
    });

    test('A COAT AND A SUIT ARE THE GARMENT ALL THE WAY UP', () {
      // **`--top` is "shirt, jacket or training-top body + upper arms"** — the
      // CSS's own words, and the port had no such colour: the torso and the
      // bicep both read `--kit` directly. A charcoal overcoat came out with
      // green shoulders and a green crescent of shirt above its own collar,
      // because the overlay's shoulders are narrower than the torso under them.
      for (final id in ['coat', 'suit']) {
        expect(outfitPalette(id).top, isNotNull, reason: '$id is a top only');
      }
      // And the two that keep the club on his back do NOT override it: the
      // kit is the zero point and the tracksuit's whole point is being the
      // club's colour, stripes and all.
      expect(outfitPalette('kit').top, isNull);
      expect(outfitPalette('tracksuit').top, isNull);
    });

    test('and an unknown outfit is the kit, not a hole', () {
      expect(outfitPalette('nonesuch'), outfitPalette('kit'));
      expect(outfitPalette(null), outfitPalette('kit'));
    });
  });

  group('the figure stands ON its shadow', () {
    /// Where the rig sits inside its own box, as a fraction of that box.
    ///
    /// The shadow is laid out in FRACTIONS of the box and the figure's vertical
    /// offsets — the sink, the bob, the sway, the shiver — were art-unit numbers
    /// applied as logical pixels. So this fraction moved with the box's size
    /// while the shadow's did not, and at any height but the one they were tuned
    /// at he stood above his own shadow.
    double rigFraction(WidgetTester tester) {
      final box = tester.getRect(find.byType(ManagerWalker));
      final rig = tester.getRect(find.byKey(const ValueKey('manager-walker')));
      return (rig.top - box.top) / box.height;
    }

    testWidgets('AT EVERY SIZE, not just the one it was tuned at', (
      tester,
    ) async {
      await pumpWalker(tester, height: walkerHeight);
      final small = rigFraction(tester);
      await pumpWalker(tester, height: walkerHeight * 2.5);
      final large = rigFraction(tester);
      expect(
        large,
        closeTo(small, 0.0005),
        reason: 'the rig sits at a different place in a bigger box',
      );
    });

    testWidgets('and he is SUNK into it rather than perched on it', (
      tester,
    ) async {
      // The boot art carries its own sole below the footline, so the contact
      // has to be the ground line through the middle of the shadow rather than
      // its top edge. A zero offset would put the rig's box exactly on the
      // box's top.
      await pumpWalker(tester, height: walkerHeight * 2);
      expect(rigFraction(tester), greaterThan(0));
    });
  });

  group('a hat and the hair under it', () {
    /// Every clip applied to a head layer, as a fraction of the box's height.
    List<double> clipsIn(WidgetTester tester) => [
      for (final clip in tester.widgetList<ClipRect>(find.byType(ClipRect)))
        if (clip.clipper != null)
          clip.clipper!.getClip(const Size(120, 170)).top / 170,
    ];

    testWidgets('A CAP HIDES THE HAIR COMING THROUGH IT', (tester) async {
      // A mohawk's fin stood clear of the crown. The hat is drawn over the hair,
      // so whatever the hat's own shape covers was already hidden — what came
      // through was the hair ABOVE it.
      await pumpWalker(
        tester,
        look: {'style': 'mohawk', 'hat': 'cap', 'hair': '#3a2a1c'},
      );
      final clips = clipsIn(tester);
      expect(
        clips,
        isNotEmpty,
        reason: 'the hair is not clipped, so the fin still comes through',
      );
      // At the cap's own brow, and BOTH hair layers get it — a fin has a back
      // half too.
      final atBrow = clips.where((c) => (c - 30.5 / 170).abs() < 1e-9);
      expect(atBrow.length, greaterThanOrEqualTo(1));
    });

    testWidgets('AND A HEADBAND HIDES NOTHING', (tester) async {
      // Four of them are bands rather than hats. Clipping the hair for those
      // would shave the top off his head, which is a worse bug than the one
      // being fixed.
      await pumpWalker(
        tester,
        look: {'style': 'mohawk', 'hat': 'headband', 'hair': '#3a2a1c'},
      );
      expect(clipsIn(tester), isEmpty, reason: 'the headband shaved his head');
    });

    testWidgets('and bare-headed hides nothing either', (tester) async {
      await pumpWalker(
        tester,
        look: {'style': 'mohawk', 'hat': 'none', 'hair': '#3a2a1c'},
      );
      expect(clipsIn(tester), isEmpty);
    });
  });
  group('AN IDLE MUST NOT PIN A WALKING ARM', () {
    // **Reported as "the manager arm keeps getting stuck".** The idle pose pins
    // `armNear`/`armFar`, `_arm` reads `posed ?? _sample(track, t)`, and a
    // pinned angle replaces the swing outright — so the moment the dugout cam's
    // idle reached the diorama his arms stopped moving and stayed stopped.
    //
    // The idle was written for a PLANTED man, where there is no stride to
    // disagree with.
    testWidgets('a walking man keeps his swing', (tester) async {
      const idle = (
        armNear: 12.0,
        armFar: -12.0,
        foreNear: -40.0,
        foreFar: -40.0,
        head: 3.0,
        body: 1.0,
        bodyLift: 0.0,
        legs: null,
        kickThigh: null,
        kickShin: null,
        finger: 0.0,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SizedBox(
                width: 200,
                height: 300,
                child: ManagerWalker(
                  kit: Color(0xFF4CAF50),
                  skin: Color(0xFFE8B98A),
                  hair: Color(0xFF3A2A1A),
                  idle: idle,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('manager-walker')),
                  )
                  .painter!
              as dynamic;
      expect(painter.pose?.armNear, isNull, reason: 'the swing was overridden');
      expect(painter.pose?.armFar, isNull);
      // And the joints the WALK does not drive are still the idle's.
      expect(painter.pose?.body, idle.body);
    });
  });

  test('THE CARRY IS REBASED, not copied off the JS', () {
    // The JS hangs its forearm at a static -52 and folds to -110 — a delta of
    // 58. The port rebased that rest (-9 to -31, because -38/-68 put the
    // forearm horizontal with the shoulder swing on top), so copying -110
    // across folded the arm forty degrees too far. Reported as the ball carry
    // looking odd.
    expect(carryFore, greaterThan(-110));
    expect(carryFore, lessThan(carryArm));
  });


  group('the ball in his hands', () {
    // **The JS builds a whole second SVG for this**, `.ps-hold-arm`, and its own
    // comment says what its absence looks like: the arm that should close round
    // a carried ball was always behind it and *he looked like he was balancing
    // it*. Which is how it was reported here.
    const ball = SizedBox(key: ValueKey('the-ball'), width: 12, height: 12);

    testWidgets('THE NEAR ARM IS DRAWN AGAIN, OVER IT, while carrying', (
      tester,
    ) async {
      await pumpWalker(tester, carrying: true, ballLayer: ball);
      final arm = find.byKey(const ValueKey('manager-walker-carry-arm'));
      expect(arm, findsOneWidget);

      // Over the ball, which is the whole point: paint order in a Stack is
      // child order, so the copy has to come after it.
      final children = tester
          .widget<Stack>(
            find.ancestor(of: arm, matching: find.byType(Stack)).first,
          )
          .children;
      final ballAt = children.indexWhere((c) => c.key == const ValueKey('the-ball'));
      final armAt = children.indexWhere(
        (c) => c.key == const ValueKey('manager-walker-carry-arm'),
      );
      expect(ballAt, isNonNegative);
      expect(armAt, greaterThan(ballAt));
    });

    testWidgets('and NOT while he is empty-handed', (tester) async {
      // An arm drawn twice for no reason is a duplicate that surfaces on every
      // stride.
      await pumpWalker(tester, ballLayer: ball);
      expect(
        find.byKey(const ValueKey('manager-walker-carry-arm')),
        findsNothing,
      );
    });

    testWidgets('the ball is one of HIS layers, over all of him', (
      tester,
    ) async {
      // At his boot it belongs in front of the near leg, and in his hands the
      // cradle is in front of his chest — so it is above the figure either way,
      // which is where the JS puts it too.
      await pumpWalker(tester, ballLayer: ball);
      expect(find.byKey(const ValueKey('the-ball')), findsOneWidget);
    });
  });
  testWidgets('A BEAT TICK DOES NOT REBUILD HIM', (tester) async {
    // `WalkBeat` is an `InheritedNotifier`, and DEPENDING on one rebuilds the
    // dependent every tick — the whole rig, art re-parsed, once a frame, for a
    // number its painter listens to directly. Measured at one full build per
    // frame on the customiser's preview.
    final beat = ValueNotifier<double>(0);
    addTearDown(beat.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: WalkBeat(
          notifier: beat,
          child: const Center(
            child: SizedBox(
              width: walkerWidth,
              height: walkerHeight,
              child: ManagerWalker(
                kit: _kit,
                skin: Color(0xFFEEBB8C),
                hair: Color(0xFF3A2A1C),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    var rebuilt = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is ManagerWalker) rebuilt++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    for (var i = 0; i < 5; i++) {
      beat.value += 0.1;
      await tester.pump();
    }
    expect(rebuilt, 0, reason: 'the rig was rebuilt on a clock it already listens to');
    // He still moved: the painter reads the beat without the widget rebuilding.
    expect(find.byType(ManagerWalker), findsOneWidget);
  });
  group('HIS HAIR MOVES', () {
    // **Asked for directly: "I want to be able to animate hair, and we need to
    // ensure it's not expensive and doesn't slow things down."** Both halves
    // are pinned — the shape of the motion here, and the cost by the banding
    // test below it: the hair is a matrix on a layer that is already
    // rasterised, so a swinging fringe repaints nothing at all.
    test('it LAGS the bob rather than riding it', () {
      // **A mass that arrives at the same instant the head does is painted
      // on.** The bob is `walkerHipRise`, twice a stride; the hair is a quarter
      // of that cycle behind it. Measured as the two peaks rather than asserted
      // on the formula, so the claim is about the motion.
      double argMax(double Function(double) f) {
        var best = 0.0;
        var at = 0.0;
        for (var i = 0; i < 1000; i++) {
          final t = i / 1000;
          if (f(t) > best) {
            best = f(t);
            at = t;
          }
        }
        return at;
      }

      final bobPeak = argMax(walkerHipRise);
      final hairPeak = argMax((t) => hairSwayAt(t, tilt: 0));
      // Both loops run twice a stride, so a quarter of a cycle is 0.125 in t.
      final lag = (hairPeak - bobPeak).abs() % 0.5;
      expect(
        lag < 0.5 ? lag : 0.5 - lag,
        closeTo(0.125, 0.01),
        reason: 'bob peaks at $bobPeak, hair at $hairPeak',
      );
      // Twice a stride, so half a cycle later it is back where it was.
      expect(hairSwayAt(0.5, tilt: 0), closeTo(hairSwayAt(0.0, tilt: 0), 0.001));
    });

    test('and it NEVER leaves the skull it is drawn against', () {
      // **This is a reported bug, not a precaution.** The tilt term was
      // unbounded and a GESTURE's head angle is not small — a facepalm and a
      // hands-on-head are twenty degrees and more — so the swing could reach
      // three times what the constant allows, which on a long style swings the
      // mass clean off the skull and shows the back of his head through his
      // own hair. Screenshotted from the couch.
      //
      // So the range is checked against every head angle the rig can actually
      // produce, not just the small ones.
      for (var i = 0; i <= 40; i++) {
        for (final tilt in [-90.0, -40.0, -8.0, 0.0, 8.0, 40.0, 90.0]) {
          final at = hairSwayAt(i / 40, tilt: tilt);
          expect(
            at.abs(),
            lessThanOrEqualTo(hairSwayDegrees),
            reason: 'phase ${i / 40} tilt $tilt',
          );
        }
      }
    });

    test('a head that DROPS leaves its hair behind', () {
      // The other half of a lag, and the half that reads when he is not
      // walking: the hair takes a share of the head's own angle, the other way.
      // Small angles only — see the settle test below.
      expect(hairSwayAt(0, tilt: 6), lessThan(hairSwayAt(0, tilt: -6)));
    });

    test('BUT A POSED HEAD HAS SETTLED HAIR, which is the screenshot', () {
      // **Reported with a picture: bowed forward, and the hair had swung far
      // enough to show the back of his head through it.** The clamp bounds the
      // angle and does not fix the case — 3.2 degrees of follow-through on a
      // long style with his chin on his chest still opens a parting on the
      // side of his skull. It is also wrong: hair follows a head that is
      // MOVING, and a head held in a gesture has settled.
      //
      // A facepalm, a bow and a hands-on-head are all well past this.
      for (final tilt in [-90.0, -40.0, -28.0, 28.0, 40.0, 90.0]) {
        for (var i = 0; i <= 8; i++) {
          expect(
            hairSwayAt(i / 8, tilt: tilt),
            0,
            reason: 'still swinging at tilt $tilt',
          );
        }
      }
      // And an ordinary carriage — the mood's few degrees, the idle's
      // one-degree scan — is untouched.
      expect(hairSwayAt(0.375, tilt: 2).abs(), greaterThan(1));
    });

    test('and a figure that is not moving has hair that hangs', () {
      // The customiser's twenty chips, and reduced motion.
      for (var i = 0; i <= 8; i++) {
        expect(hairSwayAt(i / 8, tilt: 5, amount: 0), 0);
      }
    });

    test('A CROP DOES NOT MOVE, and a ponytail does', () {
      // **Asked for directly: the whole hair section should not sway — only
      // the bits that would.** A close crop, a buzz, a shaved head and a
      // slicked-back style are solid against the skull and must not move by a
      // hair; a ponytail, a mullet and dreads hang and swing their full travel.
      for (final still in ['crop', 'buzz', 'shaved', 'slick']) {
        expect(hairSwayFor(still), (0, 0), reason: still);
      }
      for (final hangs in ['pony', 'mullet', 'dreads']) {
        expect(hairSwayFor(hangs).$1, 1, reason: hangs);
      }
      // A tied-back style is scraped flat at the FRONT even while its tail
      // swings — one number for the whole style would flap at his forehead.
      expect(hairSwayFor('pony').$2, lessThan(0.2));
      // And an id this build has never heard of hangs still rather than
      // flapping: a look off a newer save should degrade quietly.
      expect(hairSwayFor('somethingnew'), (0, 0));
      expect(hairSwayFor(null), (0, 0));
    });

    test('every style DECIDES, and nothing else is in the table', () {
      // The same rule `hatCrownY` keeps: add a style without deciding and the
      // build stops, rather than defaulting it to something plausible.
      for (final id in hairStyleIds) {
        expect(
          hairSwayFactor.containsKey(id),
          isTrue,
          reason: '$id does not say how much of it moves',
        );
      }
      for (final id in hairSwayFactor.keys) {
        expect(hairStyleIds, contains(id), reason: '$id is not a hairstyle');
      }
      for (final entry in hairSwayFactor.entries) {
        expect(entry.value.$1, inInclusiveRange(0, 1), reason: entry.key);
        expect(entry.value.$2, inInclusiveRange(0, 1), reason: entry.key);
      }
    });

    test('and the HEAD gives a little too, on the same clock', () {
      // A neck is not a bracket, and a rigid head is most of why the hair had
      // to carry the whole effect. Smaller than the hair's, because this joint
      // already carries the mood's carriage and the idle's scan.
      expect(headSwayDegrees, lessThan(hairSwayDegrees / 2));
      double argMax(double Function(double) f) {
        var best = double.negativeInfinity;
        var at = 0.0;
        for (var i = 0; i < 1000; i++) {
          if (f(i / 1000) > best) {
            best = f(i / 1000);
            at = i / 1000;
          }
        }
        return at;
      }

      // One motion, so the two peak together.
      expect(
        argMax((t) => headSwayAt(t)),
        closeTo(argMax((t) => hairSwayAt(t, tilt: 0)), 0.01),
      );
      expect(headSwayAt(0.3, amount: 0), 0);
    });

    testWidgets('a crop\'s hair layer is not wrapped in a turn at all', (
      tester,
    ) async {
      // The cheapest proof that nought means nought: no transform, so nothing
      // to composite and nothing to cache.
      await pumpWalker(
        tester,
        reduceMotion: false,
        look: {'style': 'crop', 'outfit': 'kit', 'build': 'regular'},
      );
      final turned = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(ManagerWalker),
              matching: find.byType(Transform),
            ),
          )
          .where((w) => w.alignment == hairPivot);
      expect(turned, isEmpty, reason: 'a crop is swinging');
    });

    testWidgets('the hair turns about the CROWN, not the face', (tester) async {
      // About the skull's centre it would slide the parting down his forehead;
      // about the box it would swing the whole head.
      expect(hairPivot.y, lessThan(0), reason: 'the pivot is below the crown');
      await pumpWalker(
        tester,
        reduceMotion: false,
        look: {'style': 'pony', 'outfit': 'kit', 'build': 'regular'},
      );
      final turned = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(ManagerWalker),
              matching: find.byType(Transform),
            ),
          )
          .where((w) => w.alignment == hairPivot);
      expect(turned, isNotEmpty, reason: 'no hair layer is turning');
    });
  });

  testWidgets('THE HEAD IS CACHED IN BANDS WHILE HE MOVES, and none at rest', (
    tester,
  ) async {
    // Six SVGs, two skull clips and eight blurred shadows tilt by the same
    // angle, and each used to be its own `_Tilt` — so a frame of walking
    // re-rasterised all of them at 3x. One boundary under one tilt made the
    // tilt a layer transform.
    //
    // **It is FOUR bands now, and that reverses the "one boundary" half.** The
    // hair moves — see `hairSwayAt` — and a fringe turning inside a single
    // boundary drags the skull, the beard, the glasses and the hat into a
    // repaint with it, which is exactly the saving the one boundary bought.
    // Split by draw order — hair behind, skull and paint, fringe, features and
    // what is worn over them — the two that move are matrices on their own
    // layers and the two that do not are never touched.
    //
    // And NOT for a still (the customiser's twenty chips), where a layer each
    // is memory for nothing.
    await pumpWalker(tester, reduceMotion: false);
    final boundaries = find.descendant(
      of: find.byType(ManagerWalker),
      matching: find.byType(RepaintBoundary),
    );
    // Two fixed bands, plus a layer for each hair mass this look actually has
    // — several styles have no back piece at all.
    expect(boundaries, findsAtLeastNWidgets(2));
    expect(boundaries.evaluate().length, lessThanOrEqualTo(4));
    await pumpWalker(tester, reduceMotion: true);
    expect(
      find.descendant(
        of: find.byType(ManagerWalker),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
  });
}
