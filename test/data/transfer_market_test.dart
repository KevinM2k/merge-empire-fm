import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/transfer_market.dart';

void main() {
  group('trigger tuning', () {
    test('values', () {
      expect(transferMatchTriggerChance, 0.07);
      expect(transferIdleTriggerChance, 0.30);
      expect(transferIdleMinIntervalMs, 900000);
      expect(transferSponsorTriggerBonus, 0.06);
    });

    test('every chance is a probability', () {
      for (final p in [
        transferMatchTriggerChance,
        transferIdleTriggerChance,
        transferSponsorTriggerBonus,
      ]) {
        expect(p, inInclusiveRange(0, 1));
      }
    });

    test('a sponsored player cannot push the match chance past certainty', () {
      expect(
        transferMatchTriggerChance + transferSponsorTriggerBonus,
        lessThan(1),
      );
    });

    test('the idle gate is 15 minutes', () {
      expect(transferIdleMinIntervalMs, 15 * 60 * 1000);
    });

    test('the post-match trigger lands near one offer per 14-match season', () {
      // The file targets roughly two offers a season across both triggers,
      // with the post-match half contributing about one.
      expect(transferMatchTriggerChance * 14, closeTo(1.0, 0.05));
    });
  });

  group('offer value', () {
    test('tier multipliers', () {
      expect(transferTierMultiplier, {
        1: 4,
        2: 6,
        3: 10,
        4: 16,
        5: 24,
        6: 36,
        7: 52,
        8: 80,
      });
    });

    test('covers every mergeable tier', () {
      // T9 is scout-only and globally unique, so it is deliberately absent.
      expect(transferTierMultiplier.keys.toSet(), {1, 2, 3, 4, 5, 6, 7, 8});
      expect(transferTierMultiplier.containsKey(9), isFalse);
    });

    test('rises with tier', () {
      for (var tier = 2; tier <= 8; tier++) {
        expect(
          transferTierMultiplier[tier]!,
          greaterThan(transferTierMultiplier[tier - 1]!),
          reason: 'tier $tier',
        );
      }
    });

    test('accelerates rather than rising linearly', () {
      for (var tier = 3; tier <= 8; tier++) {
        final step = transferTierMultiplier[tier]! - transferTierMultiplier[tier - 1]!;
        final prevStep =
            transferTierMultiplier[tier - 1]! - transferTierMultiplier[tier - 2]!;
        expect(step, greaterThan(prevStep), reason: 'tier $tier');
      }
    });

    test('the sponsor premium is +50%', () {
      expect(transferSponsorBonus, 0.5);
    });

    test('the offer floor keeps early bids from looking trivial', () {
      expect(transferMinOffer, 120);

      // A T2 card is the cheapest that can be bid for; the floor should matter
      // only at the very bottom.
      final t2 = getPlayerDef('player_t2_mid')!;
      expect(t2.sellValue * transferTierMultiplier[2]!, 150);
      expect(transferMinOffer, lessThan(t2.sellValue * transferTierMultiplier[2]!));
    });

    test('bronze rookies are not targeted', () {
      expect(transferMinTier, 2);
    });

    test('every targetable tier has a multiplier', () {
      for (var tier = transferMinTier; tier <= 8; tier++) {
        expect(transferTierMultiplier.containsKey(tier), isTrue, reason: 'tier $tier');
      }
    });
  });

  group('grudge', () {
    test('values', () {
      expect(grudgeRatingBoost, 2);
      expect(grudgeInjuryMultiplier, 2.0);
      expect(grudgeMatchDuration, 1);
    });

    test('the rating boost is modest — the rival is fired up, not better', () {
      expect(grudgeRatingBoost, lessThanOrEqualTo(3));
    });

    test('it lasts a single match', () {
      expect(grudgeMatchDuration, 1);
    });

    test('grudge matches are more physical', () {
      expect(grudgeInjuryMultiplier, greaterThan(1));
    });
  });
}
