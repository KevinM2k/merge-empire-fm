/// He is visibly suffering, or he is not.
///
/// The chain was built, tested and unreachable: the service reads the sky, the
/// engine turns it into a temperature, `comfortFor` compares that against how
/// warmly the player dressed him — and nothing drew the answer. These are about
/// the last link.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/engine/weather_engine.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

void main() {
  /// The figure at its own size, with a boundary round it to read back.
  Future<void> pumpWalker(
    WidgetTester tester, {
    String comfort = 'ok',
    ManagerLook? look,
    bool still = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Center(
          child: RepaintBoundary(
            key: const ValueKey('ink'),
            child: SizedBox(
              width: walkerWidth,
              height: walkerHeight,
              child: ManagerWalker(
                kit: const Color(0xFF4CAF50),
                skin: const Color(0xFFEEBB8C),
                hair: const Color(0xFF3A2A1C),
                look: look,
                mood: Mood.neutral,
                comfort: comfort,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Every pixel of the figure, so a change of state can be compared against
  /// another rather than described.
  Future<List<int>> pixels(WidgetTester tester) async {
    final boundary =
        tester.renderObject(find.byKey(const ValueKey('ink')))
            as RenderRepaintBoundary;
    var out = <int>[];
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      out = bytes!.buffer.asUint8List().toList();
    });
    return out;
  }

  int differences(List<int> a, List<int> b) {
    var n = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) n++;
    }
    return n;
  }

  group('coping, or not', () {
    testWidgets('a comfortable manager looks exactly as he always did', (
      tester,
    ) async {
      await pumpWalker(tester);
      final ok = await pixels(tester);
      // `ok` must be the no-op state: the customiser renders him with no comfort
      // at all and must never show the weather it is not previewing.
      await pumpWalker(tester, comfort: 'ok');
      await tester.pump(const Duration(seconds: 2));
      expect(differences(ok, await pixels(tester)), 0);
    });

    testWidgets('cold puts the pallor and the breath on him', (tester) async {
      await pumpWalker(tester);
      final ok = await pixels(tester);
      await pumpWalker(tester, comfort: 'cold');
      // Past the 1.2s fade.
      await tester.pump(const Duration(seconds: 2));
      expect(
        differences(ok, await pixels(tester)),
        greaterThan(0),
        reason: 'he is freezing and nothing on him says so',
      );
    });

    testWidgets('and hot puts the flush and the sweat on him', (tester) async {
      await pumpWalker(tester);
      final ok = await pixels(tester);
      await pumpWalker(tester, comfort: 'hot');
      await tester.pump(const Duration(seconds: 2));
      expect(
        differences(ok, await pixels(tester)),
        greaterThan(0),
        reason: 'he is sweltering and nothing on him says so',
      );
    });

    testWidgets('cold and hot are not the same picture', (tester) async {
      await pumpWalker(tester, comfort: 'cold');
      await tester.pump(const Duration(seconds: 2));
      final cold = await pixels(tester);
      await pumpWalker(tester, comfort: 'hot');
      await tester.pump(const Duration(seconds: 2));
      expect(differences(cold, await pixels(tester)), greaterThan(0));
    });

    testWidgets('the breath MOVES, and only when motion is allowed', (
      tester,
    ) async {
      // Still: the pallor reads, the puffs hold where they are.
      await pumpWalker(tester, comfort: 'cold');
      await tester.pump(const Duration(seconds: 2));
      final frozen = await pixels(tester);
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        differences(frozen, await pixels(tester)),
        0,
        reason: 'reduced motion is meant to stop it breathing',
      );

      await pumpWalker(tester, comfort: 'cold', still: false);
      await tester.pump(const Duration(seconds: 2));
      final a = await pixels(tester);
      // Most of a breath later. 2.6s a puff, so this is a different part of it.
      await tester.pump(const Duration(milliseconds: 900));
      expect(
        differences(a, await pixels(tester)),
        greaterThan(0),
        reason: 'the puff never left his mouth',
      );
    });
  });

  group('the tremble', () {
    /// The bottom third of the figure — his legs, where neither the pallor nor
    /// the flush paints anything. Any difference down here is the whole body
    /// having MOVED, which is the only thing the shiver does.
    ///
    /// The buffer is row-major, so a fraction of it is that fraction of the rows.
    List<int> legs(List<int> b) =>
        b.sublist(((b.length * 2 / 3) / 4).floor() * 4);

    testWidgets('moves the whole body, not just his face', (tester) async {
      // Same instant of the same stride in both, so the walk contributes an
      // identical pose and the shiver is all that is left.
      await pumpWalker(tester, still: false);
      final plain = legs(await pixels(tester));
      await pumpWalker(tester, comfort: 'hot', still: false);
      expect(
        differences(plain, legs(await pixels(tester))),
        0,
        reason: 'sweating is a face, not a walk — his legs must not move',
      );
      await pumpWalker(tester, comfort: 'cold', still: false);
      expect(
        differences(plain, legs(await pixels(tester))),
        greaterThan(0),
        reason: 'he is shivering and only his head knows about it',
      );
    });

    testWidgets('and stops dead under reduced motion', (tester) async {
      // Not merely frozen mid-tremble: a stopped clock left the figure sitting a
      // third of a unit to one side, which is a permanent lean rather than a
      // shiver. The JS leaves `.psv-tremble` out of its reduced-motion block and
      // keeps strobing, which reads as an omission — a 130ms tremble is exactly
      // what that setting exists to stop.
      await pumpWalker(tester);
      await tester.pump(const Duration(seconds: 2));
      final plain = legs(await pixels(tester));
      await pumpWalker(tester, comfort: 'cold');
      await tester.pump(const Duration(seconds: 2));
      expect(differences(plain, legs(await pixels(tester))), 0);
    });
  });

  group('the chain the scene reads', () {
    /// The provider does this in one line; this is the same arithmetic, so a
    /// change to either end of it shows up as a manager who is wrong rather than
    /// as a number that is.
    String comfortIn({
      required num tempC,
      required String outfit,
      String hat = 'none',
    }) => comfortFor(tempC, garmentWarmth({'outfit': outfit, 'hat': hat}));

    test('shorts in February is cold; a coat in February is not', () {
      expect(comfortIn(tempC: 3, outfit: 'kit'), 'cold');
      expect(
        comfortIn(tempC: 3, outfit: 'coat'),
        'ok',
        reason: 'dressing him sensibly must not be punished',
      );
    });

    test('a coat and a beanie in August is hot; the kit is not', () {
      expect(comfortIn(tempC: 28, outfit: 'coat', hat: 'beanie'), 'hot');
      expect(comfortIn(tempC: 28, outfit: 'kit'), 'ok');
    });

    test('a baseball cap is not insulation', () {
      // He should still be visibly freezing in shorts and a cap.
      expect(comfortIn(tempC: 2, outfit: 'kit', hat: 'cap'), 'cold');
      // The beanie is wool, and it brings its scarf.
      expect(comfortIn(tempC: 2, outfit: 'tracksuit', hat: 'beanie'), 'ok');
    });

    test('and a sunny sky makes him sweat whatever the season said', () {
      // `sunny` floors the estimate at `sunnyC`, which is the whole reason it is
      // a separate condition from `clear`: a manager in a winter coat under a
      // blazing sun has to be sweating even when the guess came from a table.
      final winter = <String, dynamic>{
        'weather': <String, dynamic>{'lat': 51.51},
      };
      final january = DateTime(2026, 1, 15, 12).millisecondsSinceEpoch;
      final coat = garmentWarmth({'outfit': 'coat', 'hat': 'beanie'});
      expect(
        comfortFor(estimatedTempC(winter, january, 'clear'), coat),
        'ok',
        reason: 'a coat in January is exactly the right call...',
      );
      expect(
        comfortFor(estimatedTempC(winter, january, 'sunny'), coat),
        'hot',
        reason: '...until the sky the player can see says otherwise',
      );
      // And the same January in shorts, which is the other end of it.
      expect(
        comfortFor(
          estimatedTempC(winter, january, 'clear'),
          garmentWarmth({'outfit': 'kit'}),
        ),
        'cold',
      );
    });
  });

  group('BUT HE DOES NOT SWEAT UNDER A MOON', () {
    // `sunny` floors the temperature, which is the JS's rule and stays in the
    // engine — and the scene draws that same condition as a MOON once the theme
    // is dark. So the manager ran with a flushed face and beads off his temple
    // under a night sky, suffering heat from a sun that is not in the picture.
    Future<String> seen(WidgetTester tester, String comfort, Brightness b) async {
      late String out;
      // An explicit inner `Theme`, not `MaterialApp.theme`: that one is picked
      // against the platform brightness and will not do as it is told.
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: ThemeData(brightness: b),
            child: Builder(
              builder: (context) {
                out = sceneComfort(context, comfort);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return out;
    }

    testWidgets('the heat comes off in the dark', (tester) async {
      expect(await seen(tester, 'hot', Brightness.dark), 'ok');
      expect(await seen(tester, 'hot', Brightness.light), 'hot');
    });

    testWidgets('and the COLD does not — a night is colder, not warmer', (
      tester,
    ) async {
      expect(await seen(tester, 'cold', Brightness.dark), 'cold');
      expect(await seen(tester, 'cold', Brightness.light), 'cold');
    });

    testWidgets('and `ok` is left alone either way', (tester) async {
      expect(await seen(tester, 'ok', Brightness.dark), 'ok');
      expect(await seen(tester, 'ok', Brightness.light), 'ok');
    });

    test('the ENGINE is untouched — a fixture compares that number', () {
      // The divergence is the scene's, not the model's: `estimatedTempC` still
      // floors a sunny sky, whatever the app's theme is set to.
      const winter = <String, dynamic>{};
      final january = DateTime.utc(2026, 1, 15).millisecondsSinceEpoch;
      expect(
        estimatedTempC(winter, january, 'sunny'),
        greaterThanOrEqualTo(hotC),
      );
    });
  });
}
