/// The AdMob unit ids, against the shipped app's.
///
/// **A wrong unit id does not fail — it just never pays.** The gate opens, the
/// countdown runs, the player watches nothing and the reward never lands, which
/// reads as the reward being broken rather than the placement being wrong. And
/// the ids are per PLATFORM: an Android unit requested from iOS is a no-fill,
/// for ever, silently. Neither failure has a stack trace, which is exactly why
/// they are pinned rather than trusted.
///
/// Dumped by `tool/dump_ad_units_reference.mjs` from `src/engine/energyEngine.js`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/ad_units.dart';

void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/ad_units_reference.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final android = (fixture['android'] as Map).cast<String, String>();
  final ios = (fixture['ios'] as Map).cast<String, String>();

  test('EVERY PLACEMENT THE SHIPPED APP SERVES IS HERE', () {
    for (final table in [android, ios]) {
      for (final placement in table.keys) {
        expect(
          rewardedByPlacementAndroid.containsKey(placement),
          isTrue,
          reason: '$placement is not in the port at all',
        );
      }
    }
  });

  test('AND EVERY ID IS BYTE-EXACT, on both platforms', () {
    for (final entry in android.entries) {
      expect(
        rewardedByPlacementAndroid[entry.key],
        entry.value,
        reason: 'android ${entry.key}',
      );
    }
    for (final entry in ios.entries) {
      expect(
        rewardedByPlacementIos[entry.key],
        entry.value,
        reason: 'ios ${entry.key}',
      );
    }
  });

  test('THE TWO PLATFORMS NEVER SHARE AN ID', () {
    // An Android unit requested from iOS never fills, and the mistake looks
    // exactly like an ad network having no inventory.
    for (final placement in android.keys) {
      expect(
        rewardedByPlacementAndroid[placement],
        isNot(rewardedByPlacementIos[placement]),
        reason: placement,
      );
    }
  });

  test('and `cosmetic_pack` IS A DIVERGENCE — the port has a unit the JS has not', () {
    // **This flipped, and the direction matters.** The placement used to be
    // null on both sides: a console job nobody had done, not a porting gap. The
    // units now exist and came from the AdMob console rather than from
    // `energyEngine.js`, so the port is AHEAD of the spec here.
    //
    // Pinned rather than deleted, because the assertion that still earns its
    // keep is the one about the fixture: a later fixture regeneration that
    // suddenly carries `cosmetic_pack` means the JS grew its own unit, and
    // whether the two agree is then a real question. Until it does, this is the
    // divergence stated out loud — which is what CLAUDE.md asks of one.
    expect(rewardedByPlacementAndroid['cosmetic_pack'], isNotNull);
    expect(rewardedByPlacementIos['cosmetic_pack'], isNotNull);
    expect(android.containsKey('cosmetic_pack'), isFalse);
    expect(ios.containsKey('cosmetic_pack'), isFalse);
  });
}
