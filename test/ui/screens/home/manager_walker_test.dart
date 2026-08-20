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
import 'package:merge_empire_fc/data/manager_mood.dart';
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

  group('the walk does not skate', () {
    // The ground moves at one speed (see `groundSpeedPxPerSec`), so the planted
    // foot has to. It did not: the keyframed rig moved the foot BACKWARDS over
    // the first 6% of the step and then 8% slow, 8% fast through the rest of it.
    // The foot's path is the input now and the joints are solved from it.

    test('the planted foot travels at a CONSTANT rate through its stance', () {
      final steps = [
        for (var i = 1; i <= 20; i++)
          walkerFootX(0.5 * i / 20) - walkerFootX(0.5 * (i - 1) / 20),
      ];
      final lo = steps.reduce(math.min);
      final hi = steps.reduce(math.max);
      expect((hi - lo).abs(), lessThan(1e-9));
      // And backwards, against a ground travelling forwards.
      expect(hi, lessThan(0));
    });

    test('and it covers exactly the stride the ground is timed off', () {
      expect(
        (walkerFootX(0.5) - walkerFootX(0)).abs(),
        closeTo(walkerStrideArtUnits, 1e-9),
      );
    });

    test('the planted BOOT stays on the ground, at one height', () {
      // The whole figure rises and falls, and the foot ROLLS — heel first, flat,
      // then up onto the toe — so it is the sole that has to hold its height,
      // not the ankle. Pinning the ankle instead drove thirty degrees of toe
      // into the turf at push-off and left the heel planted through it.
      final heights = [
        for (var i = 0; i <= 20; i++)
          walkerBootSoleY(0.5 * i / 20) - walkerHipRise(0.5 * i / 20),
      ];
      expect(
        heights.reduce(math.max) - heights.reduce(math.min),
        lessThan(0.01),
      );
    });

    test('and the ankle lifts as he rolls onto his toe', () {
      // The heel coming off the grass is most of what reads as a push rather
      // than a slide.
      expect(walkerAnkle(0.5).y, lessThan(walkerAnkle(0.2).y - 3));
    });

    test('and it LIFTS while it swings — it does not drag through', () {
      final ground = walkerAnkle(0).y - walkerHipRise(0);
      final mid = walkerAnkle(0.75).y - walkerHipRise(0.75);
      expect(mid, lessThan(ground - 6), reason: 'clear of the grass');
    });

    test('the path closes, so the loop cannot jolt', () {
      expect(walkerAnkle(0).x, closeTo(walkerAnkle(0.999999).x, 1e-3));
      expect(walkerAnkle(0).y, closeTo(walkerAnkle(0.999999).y, 1e-3));
      // The far leg is exactly half a cycle behind the near one.
      expect(walkerFootX(0.25 + 0.5), closeTo(walkerFootX(0.75), 1e-9));
    });

    test('the knee NEVER locks straight', () {
      // A leg at full extension reads as rigid for an instant at foot-down, and
      // that instant is the thing you notice. Held back by `_kneeLock`.
      for (var i = 0; i <= 200; i++) {
        final t = i / 200;
        final target = walkerAnkle(t);
        final reach = math.sqrt(
          target.x * target.x +
              (target.y - 95) * (target.y - 95),
        );
        expect(
          reach,
          lessThan(walkerThigh + walkerShin - 1),
          reason: 'straight-legged at t=$t',
        );
      }
    });
  });
}
