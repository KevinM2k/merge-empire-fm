/// What a rewarded video on the free shelf grants.
///
/// **Both mechanics existed in the port and neither could be reached.** The
/// match, the cup and the fixture preview all read `luckyBootReady`; the
/// cooldown reads `matchCooldownFreeUntil`. What was missing was the only thing
/// that sets them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/free_shelf_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

final int _t0 = DateTime(2026, 4, 14, 10).millisecondsSinceEpoch;

void main() {
  setUp(() => setClock(() => _t0));
  tearDown(resetClock);

  group('the cooldown skip', () {
    test('buys five minutes and spends one of three', () {
      final s = createDefaultState();
      expect(canWatchMatchCooldownAd(s), isTrue);
      grantMatchCooldownAd(s);
      expect(matchCooldownFree(s), isTrue);
      expect(
        (s['boosts'] as Map)['matchCooldownFreeUntil'],
        _t0 + matchCooldownFreeMs,
      );
      expect(matchCooldownAdsUsed(s), 1);
    });

    test('and three a day is the cap', () {
      final s = createDefaultState();
      for (var i = 0; i < matchCooldownAdCapPerDay; i++) {
        grantMatchCooldownAd(s);
      }
      expect(matchCooldownAdsUsed(s), matchCooldownAdCapPerDay);
      expect(canWatchMatchCooldownAd(s), isFalse);
    });

    test('A DIFFERENT DAY IS A FRESH COUNT, and the day is wall-clock', () {
      // The JS stamps `toDateString()`, so this is the same calendar day rather
      // than a rolling 24 hours — which is what makes the cap read as "three a
      // day" to a player.
      final s = createDefaultState();
      for (var i = 0; i < matchCooldownAdCapPerDay; i++) {
        grantMatchCooldownAd(s);
      }
      final tomorrow = _t0 + 24 * 60 * 60 * 1000;
      setClock(() => tomorrow);
      expect(matchCooldownAdsUsed(s), 0);
      expect(canWatchMatchCooldownAd(s), isTrue);
    });

    test('THE DAY IS RE-READ ON THE GRANT, not captured before the ad', () {
      // A video started at 23:59 and finished at 00:01 belongs to the day it
      // FINISHED. The JS captures it first, which spends yesterday's budget on
      // a boost the player is holding today.
      final s = createDefaultState();
      final lateLastNight = DateTime(
        2026,
        4,
        14,
        23,
        59,
      ).millisecondsSinceEpoch;
      setClock(() => lateLastNight);
      grantMatchCooldownAd(s);
      expect(matchCooldownAdsUsed(s), 1);

      final justAfterMidnight = DateTime(2026, 4, 15, 0, 1)
          .millisecondsSinceEpoch;
      setClock(() => justAfterMidnight);
      expect(matchCooldownAdsUsed(s), 0, reason: 'yesterday was charged twice');
      grantMatchCooldownAd(s);
      expect(matchCooldownAdsUsed(s), 1);
    });

    test('and a running boost is not sold again', () {
      final s = createDefaultState();
      grantMatchCooldownAd(s);
      expect(canWatchMatchCooldownAd(s), isFalse);
      expect(matchCooldownFreeMinsLeft(s), 5);
    });

    test('the countdown rounds UP — forty seconds left is still a minute', () {
      final s = createDefaultState();
      (s['boosts'] as Map<String, dynamic>)['matchCooldownFreeUntil'] =
          _t0 + 40000;
      expect(matchCooldownFreeMinsLeft(s), 1);
      (s['boosts'] as Map<String, dynamic>)['matchCooldownFreeUntil'] = _t0;
      expect(matchCooldownFreeMinsLeft(s), 0);
      expect(matchCooldownFree(s), isFalse);
    });
  });

  group('the lucky boot', () {
    test('is set ready, and DOES NOT push the coin price up', () {
      // `luckyBootUses` is what makes the next PAID boot dearer, and a free one
      // must not. The JS says so in its own comment, and it is the kind of thing
      // that looks like an oversight when it is a decision.
      final s = createDefaultState();
      final shop = s['shop'] as Map<String, dynamic>;
      final before = shop['luckyBootUses'];
      expect(luckyBootHeld(s), isFalse);
      grantLuckyBootAd(s);
      expect(luckyBootHeld(s), isTrue);
      expect(shop['luckyBootUses'], before);
    });
  });

  test('and a save missing the blocks entirely grows them', () {
    final bare = <String, dynamic>{};
    grantMatchCooldownAd(bare);
    grantLuckyBootAd(bare);
    expect(matchCooldownFree(bare), isTrue);
    expect(luckyBootHeld(bare), isTrue);
    expect(matchCooldownAdsUsed(null), 0);
    expect(matchCooldownFree(null), isFalse);
    expect(luckyBootHeld(null), isFalse);
  });
}
