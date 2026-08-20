/// The weather is on the screen.
///
/// Every layer is present in every condition and only its opacity says which one
/// is on — that is what makes changing the sky free, and it is also what leaves a
/// test nothing to find by type. So these assert through the layer keys, and the
/// question each one asks is "would a player see this".
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/engine/weather_engine.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_weather.dart';

void main() {
  Future<void> pumpScene(
    WidgetTester tester, {
    String condition = 'clear',
    int tier = 1,
    Brightness brightness = Brightness.dark,
    void Function()? onThunder,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          // No looping ticker anywhere in the scene, which is the only reason a
          // test of it can settle at all.
          disableAnimations: true,
        ),
        child: Theme(
          data: ThemeData(brightness: brightness),
          child: Scaffold(
            body: PitchScene(
              mood: Mood.neutral,
              tier: tier,
              condition: condition,
              onThunder: onThunder,
              walkerBottom: 150 + walkerBottomClearance,
              walker: const SizedBox(width: 120, height: 170),
            ),
          ),
        ),
      ),
    ),
  );

  /// What a player would see of one layer: 0 is nothing at all.
  double shown(WidgetTester tester, String layer) {
    final finder = find.byKey(weatherLayerKey(layer));
    expect(finder, findsOneWidget, reason: 'no $layer layer in the scene');
    return tester
        .widget<AnimatedOpacity>(
          find.descendant(
            of: finder,
            matching: find.byType(AnimatedOpacity),
            matchRoot: true,
          ),
        )
        .opacity;
  }

  group('a clear sky', () {
    testWidgets('draws no weather at all', (tester) async {
      await pumpScene(tester);
      for (final layer in const [
        'sun',
        'overcast',
        'rain',
        'snow',
        'fog',
        'wind',
        'ground-snow',
        'prints',
      ]) {
        expect(shown(tester, layer), 0, reason: '$layer showed on a clear day');
      }
    });

    testWidgets('but the clouds are always there', (tester) async {
      await pumpScene(tester);
      expect(
        shown(tester, 'clouds'),
        1,
        reason: 'the clouds are the sky, not a condition',
      );
    });
  });

  group('each condition shows its own layer', () {
    testWidgets('and nothing else', (tester) async {
      // The particle layers only. `overcast` and `clouds` are shared across
      // several skies and are asserted on their own below.
      const owned = {
        'sunny': 'sun',
        'rain': 'rain',
        'snow': 'snow',
        'fog': 'fog',
        'wind': 'wind',
      };
      for (final entry in owned.entries) {
        await pumpScene(tester, condition: entry.key);
        for (final layer in owned.values) {
          expect(
            shown(tester, layer),
            layer == entry.value ? 1 : 0,
            reason: '${entry.key} showed the $layer layer',
          );
        }
      }
    });

    testWidgets('every condition the engine can name is drawable', (
      tester,
    ) async {
      // The list this is checked against is the ENGINE's, so a ninth condition
      // cannot be added without something here failing.
      for (final condition in conditions) {
        await pumpScene(tester, condition: condition);
        final lit = [
          for (final layer in const [
            'sun',
            'overcast',
            'rain',
            'snow',
            'fog',
            'wind',
          ])
            if (shown(tester, layer) > 0) layer,
        ];
        if (condition == 'clear') {
          expect(
            lit,
            isEmpty,
            reason: 'clear is a pleasant day and draws none',
          );
        } else {
          expect(
            lit,
            isNotEmpty,
            reason: '$condition looks exactly like a clear sky',
          );
        }
      }
    });
  });

  group('a storm', () {
    testWidgets('is rain PLUS lightning, not a condition of its own', (
      tester,
    ) async {
      await pumpScene(tester, condition: 'storm');
      expect(
        shown(tester, 'rain'),
        1,
        reason: 'a thunderstorm with no rain in it',
      );
      expect(shown(tester, 'overcast'), 1);
    });

    testWidgets('and its flash is the one layer that goes OVER him', (
      tester,
    ) async {
      await pumpScene(tester, condition: 'storm');
      // Every layer fills the scene, so the only thing that separates them is
      // paint order — and the CSS is explicit about it: the shower is a curtain
      // BEHIND the subject of the shot (`.ps-rain` 3 against `.ps-walker` 4),
      // and a flash that lights the whole ground lights the man standing in it.
      final keys = tester
          .widget<Stack>(
            find
                .descendant(
                  of: find.byType(PitchScene),
                  matching: find.byType(Stack),
                )
                .first,
          )
          .children
          .map((c) => c.key)
          .toList();
      final air = keys.indexOf(const ValueKey('pitch-weather-air'));
      final walker = keys.indexOf(const ValueKey('pitch-walker'));
      final lightning = keys.indexOf(const ValueKey('pitch-weather-lightning'));
      expect(air, greaterThan(-1));
      expect(walker, greaterThan(air), reason: 'the rain fell in front of him');
      expect(
        lightning,
        greaterThan(walker),
        reason: 'the flash lit everything except the man in it',
      );
    });

    testWidgets('nothing strikes under reduced motion', (tester) async {
      var thunder = 0;
      await pumpScene(tester, condition: 'storm', onThunder: () => thunder++);
      // Well past the 4–13s the JS waits between strikes.
      await tester.pump(const Duration(seconds: 20));
      expect(
        thunder,
        0,
        reason: 'a full-screen flash is what that setting exists to prevent',
      );
    });
  });

  group('snow', () {
    testWidgets('settles on the pitch and leaves prints', (tester) async {
      await pumpScene(tester, condition: 'snow');
      expect(
        shown(tester, 'ground-snow'),
        1,
        reason: 'falling snow that never settles is a screen effect',
      );
      expect(shown(tester, 'prints'), 1, reason: 'he walked through it');
    });

    testWidgets('and its sky is PALE, not the wet grey', (tester) async {
      await pumpScene(tester, condition: 'snow');
      // A white pitch under a summer-blue sky is the one combination that makes
      // the whole scene look broken, so snow takes the overcast layer too.
      expect(shown(tester, 'overcast'), 1);
    });

    testWidgets('the prints ride the ground at the GROUND\'s own period', (
      tester,
    ) async {
      await pumpScene(tester, condition: 'snow');
      final prints = tester.widget<WeatherPrints>(find.byType(WeatherPrints));
      // A print that slides against the grass is the mistake the eye catches
      // first, so the two periods have to be the same arithmetic.
      expect(
        prints.scrollDuration.inMicroseconds,
        (printSegmentWidth / groundSpeedPxPerSec(Mood.neutral) * 1e6).round(),
      );
    });

    testWidgets('and the mask is cut at his boot, not at the frame', (
      tester,
    ) async {
      await pumpScene(tester, condition: 'snow');
      final prints = tester.widget<WeatherPrints>(find.byType(WeatherPrints));
      // He stands at `w * 0.45 - 57` with his feet ~59 units into the figure, so
      // the cut lands a shade past 45% of whatever the scene turns out to be —
      // measured, because a hardcoded width tests the harness and not the scene.
      final w = tester.getRect(find.byType(PitchScene)).width;
      expect(prints.contactFraction, closeTo((w * 0.45 - 57 + 59) / w, 1e-9));
      expect(
        prints.contactFraction,
        greaterThan(0.45),
        reason: 'the trail must reach his boot, not stop short of it',
      );
    });
  });

  group('the shared layers', () {
    testWidgets('overcast covers every wet sky, because it never rains out of '
        'a clear one', (tester) async {
      for (final condition in const [
        'cloudy',
        'rain',
        'wind',
        'storm',
        'snow',
      ]) {
        await pumpScene(tester, condition: condition);
        expect(
          shown(tester, 'overcast'),
          1,
          reason: '$condition sat under a blue sky',
        );
      }
      for (final condition in const ['clear', 'sunny', 'fog']) {
        await pumpScene(tester, condition: condition);
        expect(
          shown(tester, 'overcast'),
          0,
          reason: '$condition was dimmed for no reason',
        );
      }
    });

    testWidgets('and fog is the one sky with no clouds in it', (tester) async {
      await pumpScene(tester, condition: 'fog');
      expect(
        shown(tester, 'clouds'),
        0,
        reason: 'you cannot see a cloud through fog',
      );
    });
  });

  group('the print tile', () {
    test('divides by the gap an EVEN number of times', () {
      // Or the near and far foot stop alternating across the seam, and the trail
      // reads as one boot hopping.
      expect(printSegmentWidth % 70, 0);
      expect((printSegmentWidth / 70).round().isEven, isTrue);
    });

    test('and is the same tile the ground scrolls', () {
      // The prints share the turf's period; sharing the period only pins them to
      // the grass if they also share the width it is measured against.
      expect(printSegmentWidth, groundSegmentWidth);
    });
  });

  group('a strike', () {
    /// The lightning on its own, with motion allowed. Not through the scene:
    /// every other layer would be ticking, and this is the one part of the
    /// weather whose whole point is that it does NOT loop.
    Future<void> pumpBolt(
      WidgetTester tester, {
      required String condition,
      required void Function() onThunder,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeatherLightning(
            condition: condition,
            onThunder: onThunder,
            // Fixed, so the 4–13s wait and the near/far roll are the same
            // every run.
            random: math.Random(7),
          ),
        ),
      ),
    );

    Finder bolt() => find.descendant(
      of: find.byType(WeatherLightning),
      matching: find.byType(CustomPaint),
    );

    testWidgets('costs nothing at all until it fires', (tester) async {
      await pumpBolt(tester, condition: 'storm', onThunder: () {});
      expect(
        bolt(),
        findsNothing,
        reason: 'an idle flash still costs a paint every frame',
      );
      await tester.pump(const Duration(seconds: 3, milliseconds: 900));
      expect(bolt(), findsNothing, reason: 'it struck inside the 4s floor');
    });

    testWidgets('and the LIGHT arrives before the SOUND', (tester) async {
      var thunder = 0;
      await pumpBolt(tester, condition: 'storm', onThunder: () => thunder++);

      // Find the flash. The wait is 4–13s, so this covers the whole range.
      var struck = false;
      for (var i = 0; i < 140; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (bolt().evaluate().isNotEmpty) {
          struck = true;
          break;
        }
      }
      expect(struck, isTrue, reason: 'a storm with no lightning in it');
      // **This is the whole trick.** Light arrives instantly and sound does not,
      // so a simultaneous flash and bang reads as a sound effect while a gap of
      // even half a second reads as distance.
      expect(thunder, 0, reason: 'the thunder beat the flash');

      // The longest the JS ever leaves it is 2.3s.
      await tester.pump(const Duration(milliseconds: 2400));
      expect(thunder, greaterThan(0), reason: 'the flash was silent');
    });

    testWidgets('and a storm that passes takes its thunder with it', (
      tester,
    ) async {
      var thunder = 0;
      await pumpBolt(tester, condition: 'storm', onThunder: () => thunder++);
      for (var i = 0; i < 140; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (bolt().evaluate().isNotEmpty) break;
      }
      // The sky clears between the flash and the bang. The bang belongs to a
      // storm that is no longer happening.
      await pumpBolt(tester, condition: 'clear', onThunder: () => thunder++);
      await tester.pump(const Duration(seconds: 20));
      expect(thunder, 0, reason: 'thunder rolled in over a clear sky');
      expect(bolt(), findsNothing);
    });
  });

  group('it actually paints', () {
    /// **A structural test cannot see a silent painter.** A gradient with a bad
    /// transform, a shader anchored to the wrong point, a particle field placed
    /// off the top of the box — every one of those leaves the layer present, at
    /// full opacity, drawing nothing. So this renders the layer and adds up the
    /// alpha it laid down.
    ///
    /// Summed rather than counted: a veil covers every pixel with a little, so
    /// "how many pixels have any ink at all" saturates and cannot tell a sun in
    /// the sky from an empty one.
    Future<int> inkFor(WidgetTester tester, Widget layer) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: RepaintBoundary(
              key: const ValueKey('ink'),
              child: SizedBox(width: 240, height: 320, child: layer),
            ),
          ),
        ),
      );
      // **Past the fade.** Every layer is keyed, so a second pump in the same
      // test reuses the element and `AnimatedOpacity` LERPS from whatever the
      // last condition left it at — capture straight away and you photograph
      // the sky you were comparing against.
      await tester.pump(const Duration(seconds: 2));
      final boundary =
          tester.renderObject(find.byKey(const ValueKey('ink')))
              as RenderRepaintBoundary;
      // `toImage` rasterises on the real engine, so it needs the real async
      // zone — inside the test's fake one the future simply never completes.
      var ink = 0;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
          ink += bytes.getUint8(i);
        }
      });
      return ink;
    }

    for (final condition in const ['rain', 'storm', 'snow', 'fog', 'wind']) {
      testWidgets('$condition puts something in the air', (tester) async {
        final ink = await inkFor(tester, WeatherAir(condition: condition));
        expect(ink, greaterThan(0), reason: '$condition drew nothing at all');
      });
    }

    testWidgets('and a clear sky puts nothing there', (tester) async {
      expect(
        await inkFor(tester, const WeatherAir(condition: 'clear')),
        0,
        reason: 'a clear day cost the scene a layer of paint',
      );
    });

    testWidgets('the sun is in the sky, and only for `sunny`', (tester) async {
      final sunny = await inkFor(tester, const WeatherSky(condition: 'sunny'));
      final clear = await inkFor(tester, const WeatherSky(condition: 'clear'));
      // Both have clouds. The sun is what `sunny` adds, and its bloom is wide.
      expect(clear, greaterThan(0), reason: 'the clouds vanished');
      expect(
        sunny,
        greaterThan(clear),
        reason: 'sunny drew no more sky than a plain clear day',
      );
    });

    testWidgets('snow whitens the pitch, and his prints are in it', (
      tester,
    ) async {
      expect(
        await inkFor(tester, const WeatherGroundSnow(condition: 'snow')),
        greaterThan(0),
      );
      final prints = await inkFor(
        tester,
        const WeatherPrints(
          condition: 'snow',
          scrollDuration: Duration(seconds: 5),
          contactFraction: 0.45,
        ),
      );
      expect(prints, greaterThan(0), reason: 'no prints in the snow');
    });

    testWidgets('and the trail stops at his boot', (tester) async {
      // The mask is the whole reason these read as HIS prints: nothing may be
      // drawn ahead of where he is standing.
      final short = await inkFor(
        tester,
        const WeatherPrints(
          condition: 'snow',
          scrollDuration: Duration(seconds: 5),
          contactFraction: 0.2,
        ),
      );
      final long = await inkFor(
        tester,
        const WeatherPrints(
          condition: 'snow',
          scrollDuration: Duration(seconds: 5),
          contactFraction: 0.9,
        ),
      );
      expect(
        long,
        greaterThan(short),
        reason: 'the mask is not cutting the trail off at his boot',
      );
    });
  });
}
