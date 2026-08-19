/// The manager, walking.
///
/// He was one hardcoded man: a hand-transcribed crop haircut, a flat kit, no
/// hat and no face. `randomAvatar`, twelve hairstyles, four outfits, the hats,
/// the faces and `manager_mood.dart` were all ported with nothing reading them.
library;

import 'dart:io';

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
      await pumpWalker(tester, look: {...defaultManagerLook, 'hat': 'none'});
      final bare = tester.widgetList<SvgArt>(find.byType(SvgArt)).length;

      await pumpWalker(tester, look: {...defaultManagerLook, 'hat': 'crown'});
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
}
