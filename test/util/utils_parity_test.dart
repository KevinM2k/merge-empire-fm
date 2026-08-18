/// The pure half of four small utilities, against the JS they were ported from:
/// the kit colour maths, the ATK/DEF display clamp, the region code, and the
/// low-end device policy.
///
/// The kit maths is the one with a bug history. `inkFor` used to be an
/// HSL-lightness test, which is not perceived brightness — pure yellow sits at
/// the same 50% L as a mid green and reflects far more light, so a yellow kit
/// got WHITE ink and rendered invisible text on a yellow button. The colours
/// here walk the hues either side of that decision, and the round trip through
/// HSL and back is pinned too, because both directions round and a port that
/// rounds differently shifts every derived surface by a shade.
///
/// See `tool/dump_utils_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/util/device.dart';
import 'package:merge_empire_fc/util/kit_theme.dart';
import 'package:merge_empire_fc/util/region.dart';
import 'package:merge_empire_fc/util/stat_display.dart';

final Map<String, dynamic> _ref =
    jsonDecode(File('test/fixtures/utils_reference.json').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

void main() {
  group('the kit colour maths', () {
    final kit = _section('kit');

    test('parity — hex to HSL and back', () {
      for (final row in (kit['rows'] as List).cast<Map<String, dynamic>>()) {
        final hex = row['hex'] as String;
        final hsl = hexToHsl(hex);
        expect([hsl.h, hsl.s, hsl.l], row['hsl'], reason: '$hex hsl');
        expect(
          hslToHex(hsl.h, hsl.s, hsl.l),
          row['roundTrip'],
          reason: '$hex round trip',
        );
      }
    });

    test('parity — HSL to hex across the wheel', () {
      for (final row in _rows('hslToHex')) {
        expect(
          hslToHex(row['h'] as num, row['s'] as num, row['l'] as num),
          row['hex'],
          reason: 'h${row['h']} s${row['s']} l${row['l']}',
        );
      }
    });

    test('parity — luminance, contrast and the ink', () {
      expect(whiteInkMinContrast, kit['whiteInkMinContrast']);
      for (final row in (kit['rows'] as List).cast<Map<String, dynamic>>()) {
        final hex = row['hex'] as String;
        expect(relLuminance(hex), row['luminance'], reason: '$hex luminance');
        expect(
          contrastRatio(relLuminance(hex), relLuminance(inkLight)),
          row['contrastWithWhite'],
          reason: '$hex against white',
        );
        expect(
          contrastRatio(relLuminance(hex), relLuminance(inkDark)),
          row['contrastWithBlack'],
          reason: '$hex against black',
        );
        expect(inkFor(hex), row['ink'], reason: '$hex ink');
      }
    });

    test('white is the house style, and only flips where it disappears', () {
      // Dark ink wins a straight "whichever contrasts more" test on most
      // mid-tone accents, which would repaint every filled button in black.
      expect(inkFor('#4caf50'), inkLight); // the default green
      expect(inkFor('#ffd700'), inkDark); // yellow, the case that broke
      expect(inkFor('#ff9800'), inkDark); // orange, the same mush
      expect(inkFor('#000000'), inkLight);
      expect(inkFor('#ffffff'), inkDark);
      // And the green really does contrast BETTER with black while keeping
      // white — which is the whole reason the test is a threshold.
      expect(
        contrastRatio(relLuminance('#4caf50'), relLuminance(inkDark)),
        greaterThan(
          contrastRatio(relLuminance('#4caf50'), relLuminance(inkLight)),
        ),
      );
    });

    test('parity — the saturation band and the hue rotation', () {
      for (final row in (kit['rows'] as List).cast<Map<String, dynamic>>()) {
        final hsl = hexToHsl(row['hex'] as String);
        expect(
          kitSaturation(hsl.s),
          row['saturation'],
          reason: '${row['hex']} saturation',
        );
        expect(
          kitHueRotate(hsl.h),
          row['hueRotate'],
          reason: '${row['hex']} hue rotate',
        );
      }
    });

    test('the hue rotation always takes the short way round', () {
      for (var h = 0; h < 360; h++) {
        expect(kitHueRotate(h), inInclusiveRange(-180, 179), reason: 'hue $h');
      }
      // And the default green barely moves, because it IS the reference hue.
      expect(kitHueRotate(hexToHsl('#4caf50').h).abs(), lessThanOrEqualTo(1));
    });

    test('every pattern kit has a fixed rotation', () {
      expect(patternHueRotate.keys, hasLength(6));
      for (final entry in patternHueRotate.entries) {
        expect(entry.value, inInclusiveRange(-180, 180), reason: entry.key);
      }
    });
  });

  group('the stat display', () {
    test('parity — clamping a split', () {
      for (final row in _rows('fifaSplit')) {
        final split = fifaSplit(row['atk'] as num, row['def'] as num);
        final want = row['split'] as Map<String, dynamic>;
        expect(split.atk, want['atk'], reason: '${row['atk']} atk');
        expect(split.def, want['def'], reason: '${row['def']} def');
      }
    });

    test('parity — with the tactic applied', () {
      for (final row in _rows('fifaSplitTactic')) {
        final split = fifaSplitTactic(
          row['atk'] as num,
          row['def'] as num,
          row['atkMult'] as num,
          row['defMult'] as num,
        );
        final want = row['split'] as Map<String, dynamic>;
        final reason =
            '${row['atk']}/${row['def']} × ${row['atkMult']}/${row['defMult']}';
        expect(split.atk, want['atk'], reason: '$reason atk');
        expect(split.def, want['def'], reason: '$reason def');
      }
      final bare = fifaSplitTactic(61.5, 58.5);
      final want = _section('fifaSplitTacticBare');
      expect(bare.atk, want['atk']);
      expect(bare.def, want['def']);
    });

    test('nothing ever leaves the 0-100 scale', () {
      // The whole point of the display being a clamp of the sim's own numbers:
      // there is nothing to reconcile, so it can only ever be out of range.
      for (final v in [-1000, -1, 0, 50, 100, 101, 1000, 99.999]) {
        final split = fifaSplit(v, v);
        expect(split.atk, inInclusiveRange(0, 100), reason: '$v');
        expect(split.def, inInclusiveRange(0, 100), reason: '$v');
      }
    });
  });

  group('the region code', () {
    final region = _section('region');

    test('the language table matches the JS', () {
      expect(langDefaultRegion, region['table']);
    });

    test('parity — what a locale tag implies', () {
      for (final row in (region['rows'] as List).cast<Map<String, dynamic>>()) {
        expect(
          regionFromLocaleTag(row['tag']),
          row['code'],
          reason: '${row['tag']}',
        );
      }
    });

    test('it is detected once and then kept', () {
      // Which is what makes it survive a later locale change.
      final state = <String, dynamic>{};
      final first = ensurePlayerRegion(state, 'fr-CA');
      expect(first.code, 'CA');
      expect(first.stored, isTrue);
      expect((state['settings'] as Map)['regionCode'], 'CA');

      // A second call with a different device locale changes nothing, and says
      // so — the caller only schedules a save when something was written.
      final second = ensurePlayerRegion(state, 'ja-JP');
      expect(second.code, 'CA');
      expect(second.stored, isFalse);
    });

    test('the save is created when there is none', () {
      final state = <String, dynamic>{};
      ensurePlayerRegion(state);
      expect((state['settings'] as Map)['locale'], 'en');
      expect((state['settings'] as Map)['regionCode'], 'GB');
    });

    test('the save language stands in for a device that will not say', () {
      final state = <String, dynamic>{
        'settings': <String, dynamic>{'locale': 'ko-KR'},
      };
      expect(getPlayerRegionCode(state), 'KR');
      // A device locale, where there is one, wins over it.
      expect(getPlayerRegionCode(state, 'de-AT'), 'AT');
      // A stored code wins over both.
      (state['settings'] as Map)['regionCode'] = 'IE';
      expect(getPlayerRegionCode(state, 'de-AT'), 'IE');
    });

    test('a save with nothing in it still lands somewhere', () {
      expect(getPlayerRegionCode(null), defaultRegion);
      expect(getPlayerRegionCode(<String, dynamic>{}), defaultRegion);
      expect(detectRegionCode(null), defaultRegion);
    });
  });

  group('the low-end device policy', () {
    final device = _section('device');

    test('the thresholds match the JS', () {
      expect(slowFrameMs, device['slowFrameMs']);
      expect(slowFrameRatio, device['slowFrameRatio']);
      expect(sampleMs, device['sampleMs']);
      expect(firstSampleDelayMs, device['firstSampleDelayMs']);
      expect(secondSampleDelayMs, device['secondSampleDelayMs']);
      expect(minSampleFrames, device['minSampleFrames']);
      expect(absurdFrameMs, device['absurdFrameMs']);
    });

    test('parity — the hardware heuristic', () {
      for (final row
          in (device['hardware'] as List).cast<Map<String, dynamic>>()) {
        expect(
          isLowEndHardware(
            memoryGb: row['memoryGb'] as num?,
            cores: row['cores'] as num?,
          ),
          row['low'],
          reason: '${row['memoryGb']}GB / ${row['cores']} cores',
        );
      }
    });

    test('a silent platform is not a slow one', () {
      // Both numbers are absent on iOS, where the hardware copes fine.
      expect(isLowEndHardware(), isFalse);
      // And memory alone never condemns a machine unless it is very low, which
      // is what stopped desktops having their crowds thinned.
      expect(isLowEndHardware(memoryGb: 4), isFalse);
      expect(isLowEndHardware(memoryGb: 2), isTrue);
    });

    test('a frame window has to be long enough to say anything', () {
      final tooShort = [for (var i = 0; i < minSampleFrames - 1; i++) 40];
      expect(slowFrameFraction(tooShort), isNull);
      expect(isStruggling(slowFrameFraction(tooShort)), isFalse);

      final enough = [for (var i = 0; i < minSampleFrames; i++) 40];
      expect(slowFrameFraction(enough), 1.0);
      expect(isStruggling(slowFrameFraction(enough)), isTrue);
    });

    test('an absurd gap is not a dropped frame', () {
      // A backgrounded app, or a modal blocking the thread for seconds: neither
      // is steady-state rendering, and counting them would condemn every device
      // that was ever interrupted.
      final smooth = [for (var i = 0; i < 30; i++) 16.7];
      expect(slowFrameFraction(smooth), 0);
      expect(slowFrameFraction([...smooth, 5000, 9000]), 0);
      // Dropping them can take a window below the floor, and then it says
      // nothing at all rather than saying "fine".
      expect(slowFrameFraction([for (var i = 0; i < 30; i++) 5000]), isNull);
    });

    test('a couple of janky frames are normal anywhere', () {
      // The ratio is deliberately high: only a sustained inability to keep up
      // should promote a device.
      final mostlyFine = [for (var i = 0; i < 30; i++) i < 3 ? 40 : 16.7];
      expect(isStruggling(slowFrameFraction(mostlyFine)), isFalse);

      final struggling = [for (var i = 0; i < 30; i++) i < 12 ? 40 : 16.7];
      expect(isStruggling(slowFrameFraction(struggling)), isTrue);
    });

    test('exactly on the threshold counts as struggling', () {
      expect(isStruggling(slowFrameRatio), isTrue);
      expect(isStruggling(slowFrameRatio - 0.001), isFalse);
      // And a frame exactly at the budget is not slow — it made it.
      final atBudget = [for (var i = 0; i < 30; i++) slowFrameMs];
      expect(slowFrameFraction(atBudget), 0);
    });
  });
}
