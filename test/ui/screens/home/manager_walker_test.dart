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
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';

const Color _kit = Color(0xFF4CAF50);

Future<void> pumpWalker(
  WidgetTester tester, {
  ManagerLook? look,
  Mood mood = Mood.neutral,
  bool reduceMotion = true,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(kitId: '#4caf50', light: false),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            height: 170,
            child: ManagerWalker(
              kit: _kit,
              skin: const Color(0xFFEEBB8C),
              hair: const Color(0xFF3A2A1C),
              look: look,
              mood: mood,
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
          parts.overHead.last,
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
          ...parts.behindHead,
          ...parts.overTorso,
          ...parts.overHead,
        ]) {
          expect(parseSvg(svg), isNotEmpty, reason: style);
        }
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
      // Monotonic, so the ladder cannot be reordered by accident.
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

    test('and an unknown outfit is the kit, not a hole', () {
      expect(outfitPalette('nonesuch'), outfitPalette('kit'));
      expect(outfitPalette(null), outfitPalette('kit'));
    });
  });
}
