/// The rules negotiation has to obey, as distinct from the numbers it produces.
///
/// The parity fixture pins the arithmetic against the JS; this pins the design
/// claims, so a fixture regenerated against a broken source still fails here.
/// Each of these is something the JS comments say out loud.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/negotiation.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

const int _now = 1700000000000;

Map<String, dynamic> _state({int cards = 8, int tier = 4}) => {
  // A grid HAS holes, so the list has to admit nulls — a real save comes through
  // jsonDecode and is nullable by construction.
  'grid': {
    'cells': <Map<String, dynamic>?>[
      for (var i = 0; i < cards; i++)
        {
          'instanceId': 'c$i',
          'definitionId': 'player_t${tier}_mid',
          'seasonsPlayed': 0,
        },
    ],
  },
  'squad': {
    'lineup': [
      for (var i = 0; i < 11; i++)
        {
          'slotId': 's$i',
          'slotPosition': 'MID',
          'cardInstanceId': i < cards ? 'c$i' : null,
        },
    ],
    'formation': '4-4-2',
  },
  'resources': {'fanCoins': 500000, 'gems': 0, 'trophies': 0},
  'clubAssets': <String, dynamic>{},
  'progression': {'currentDivision': 'regional_league'},
};

void main() {
  group('A PRO-MODE SIGNING CAN CARRY A STAMINA TRAIT', () {
    // **IT COULD NOT, AND THE FLAG IS WHY.** `rollDealCard` rolled with
    // `hardMode` defaulted to false, so `getTraitPoolForPosition` filtered the
    // stamina traits out of every signing and Deadline Day offer even in Pro
    // mode — which made the function's own promise false ("a trait that
    // arrives on a signing is worth exactly what one you rolled would be") and
    // left `hard_marathon`, "have an Iron Lungs player in your squad",
    // reachable only by paying for a re-roll. Asked about from the couch: is
    // that even unlockable?
    setUp(() {
      seeded.setSeed(4242);
      setTraitRandom(math.Random(99));
    });
    tearDown(resetTraitRandom);

    /// Traits seen over enough T8 rolls to clear the 68% trait chance.
    Set<String> rolledTraits({required bool hardMode}) {
      final def = getPlayersByTier(8).first;
      final seen = <String>{};
      for (var i = 0; i < 400; i++) {
        final card = rollDealCard(def, hardMode: hardMode);
        final id = (card?.raw['trait'] as Map?)?['id'];
        if (id is String) seen.add(id);
      }
      return seen;
    }

    test('in Pro mode, Iron Lungs is in the pool a signing draws from', () {
      expect(rolledTraits(hardMode: true), contains('iron_lungs'));
    });

    test('and outside it, never', () {
      expect(rolledTraits(hardMode: false), isNot(contains('iron_lungs')));
    });
  });

  setUp(() {
    setClock(() => _now);
    seeded.setSeed(1);
    setMergeRandom(math.Random(1));
    setTraitRandom(math.Random(1));
  });
  tearDown(() {
    resetClock();
    resetMergeRandom();
    resetTraitRandom();
    clearBus();
  });

  group('the symmetry both sides are judged by', () {
    test('cash and players of the same worth are the same offer', () {
      // A rival evaluating our player-plus-cash bid uses exactly the maths we use
      // to evaluate theirs, so a deal that reads as fair IS fair. If the two
      // sides valued differently there would be a hidden thumb on the scale.
      final s = _state();
      final ours = CardInstance.from(((s['grid'] as Map)['cells'] as List)[0])!;
      final worth = playerValue(s, ours);

      expect(offerValue(s, {'cash': worth}), worth);
      expect(offerValue(s, {'cash': 0, 'players': ['c0']}), worth);
      expect(
        offerValue(s, {'cash': 0, 'incoming': [ours.raw]}),
        worth,
      );
      // And they add, rather than one side being discounted.
      expect(
        offerValue(s, {'cash': 100, 'players': ['c0'], 'incoming': [ours.raw]}),
        100 + worth * 2,
      );
    });

    test('an unknown player is worth nothing, not a guess', () {
      final s = _state();
      expect(offerValue(s, {'cash': 0, 'players': ['ghost']}), 0);
      expect(playerValue(s, CardInstance({'definitionId': 'nope'})), 0);
      expect(playerValue(s, null), 0);
    });

    test('negative cash cannot drain an offer', () {
      final s = _state();
      expect(offerValue(s, {'cash': -9999, 'players': ['c0']}),
          playerValue(s, CardInstance.from(((s['grid'] as Map)['cells'] as List)[0])));
    });
  });

  group('asking for more', () {
    const listing = {
      'price': 10000,
      'askAnchor': 10000,
      'askCeilingMult': counterMaxMult,
    };

    test('greed can cost the sale', () {
      // Without this the worst case of asking for the moon was the original
      // price, so there was never a reason not to.
      final s = _state();
      expect(evaluateAsk(s, listing, 11000).outcome, 'accepted');
      expect(evaluateAsk(s, listing, 100000).outcome, 'withdrawn');
    });

    test('a run of accepted asks cannot compound', () {
      // The ceiling is measured from the ORIGINAL bid. Anchoring on the live
      // price let the same multiple be applied again to the new, higher number:
      // 1.3x accepted, 1.3x again accepted, with no top at all.
      final s = _state();
      final live = Map<String, dynamic>.of(listing);
      var reached = live['price'] as num;
      for (var i = 0; i < 6; i++) {
        final ask = (reached * 1.3).round();
        final verdict = evaluateAsk(s, live, ask);
        if (verdict.outcome != 'accepted') break;
        reached = verdict.price;
        // What the real caller does: the price moves, the anchor does not.
        live['price'] = reached;
      }
      expect(
        reached,
        lessThanOrEqualTo((listing['askAnchor'] as num) * counterMaxMult),
      );
    });

    test('asking for less than they already offered just takes their money', () {
      final s = _state();
      for (final ask in [null, 0, -500, 5000, 10000]) {
        final v = evaluateAsk(s, listing, ask);
        expect(v.outcome, 'accepted', reason: 'ask $ask');
        expect(v.price, 10000, reason: 'ask $ask');
      }
    });

    test('a counter never comes back below what they already agreed to', () {
      final s = _state();
      final v = evaluateAsk(s, listing, 15000);
      expect(v.outcome, 'counter');
      expect(v.price, greaterThanOrEqualTo(10000));
    });

    test('there is no third round', () {
      final s = _state();
      final haggled = {...listing, 'haggled': true};
      expect(evaluateAsk(s, haggled, 15000).outcome, 'withdrawn');
    });

    test('each buyer has their own ceiling, so there is no safe multiple', () {
      final s = _state();
      final tight = {...listing, 'askCeilingMult': counterMaxMult - ceilingJitter};
      final loose = {...listing, 'askCeilingMult': counterMaxMult + ceilingJitter};
      final ask = (10000 * counterMaxMult).round();
      expect(evaluateAsk(s, tight, ask).outcome, isNot('accepted'));
      expect(evaluateAsk(s, loose, ask).outcome, 'accepted');
    });
  });

  group('offering to buy', () {
    const listing = {
      'price': 10000,
      'offerAnchor': 10000,
      'offerMinMult': offerMinMult,
      'haggleRounds': 1,
    };

    test('a lowball does not start a conversation', () {
      final s = _state();
      expect(
        evaluateOurOffer(s, listing, {'cash': 1000}).outcome,
        'withdrawn',
      );
    });

    test('short but serious gets a number back', () {
      final s = _state();
      final v = evaluateOurOffer(s, listing, {'cash': 8000});
      expect(v.outcome, 'counter');
      // Above the halfway point, because they hold the player.
      expect(v.counterPrice, greaterThan(8000 + (10000 - 8000) * 0.5));
      expect(v.counterPrice, lessThan(10000));
    });

    test('a club with no patience says no flat, with no figure', () {
      final s = _state();
      final v = evaluateOurOffer(
        s,
        {...listing, 'haggleRounds': 0},
        {'cash': 8000},
      );
      expect(v.outcome, 'rejected');
      expect(v.counterPrice, 0);
    });

    test('their number was their number', () {
      final s = _state();
      final v = evaluateOurOffer(
        s,
        {...listing, 'sellerCounter': 9000},
        {'cash': 8500},
      );
      expect(v.outcome, 'rejected');
    });

    test('a discount is measured against the first ask, never a talked-down one', () {
      final s = _state();
      // Same offer, same anchor, but the visible price has already come down.
      final fresh = evaluateOurOffer(s, listing, {'cash': 8800});
      final talked = evaluateOurOffer(
        s,
        {...listing, 'price': 8800},
        {'cash': 8800},
      );
      expect(fresh.outcome, 'accepted');
      expect(talked.outcome, 'accepted');
      expect(talked.needed, fresh.needed);
    });

    test('a stubborn seller wants the full asking price', () {
      final s = _state();
      final stubborn = {...listing, 'offerMinMult': offerMinCeil};
      expect(evaluateOurOffer(s, stubborn, {'cash': 9999}).outcome, isNot('accepted'));
      expect(evaluateOurOffer(s, stubborn, {'cash': 10000}).outcome, 'accepted');
    });

    test('players count toward the price, not just cash', () {
      final s = _state();
      final worth = playerValue(s, CardInstance.from(((s['grid'] as Map)['cells'] as List)[0]));
      final v = evaluateOurOffer(s, listing, {
        'cash': 8800 - worth,
        'players': ['c0'],
      });
      expect(v.outcome, 'accepted');
    });
  });

  group('the transfer list', () {
    test('costs the player their place, which is the price of advertising', () {
      final s = _state();
      expect(listPlayer(s, 'c3').ok, isTrue);
      final inXI = [
        for (final l in (s['squad'] as Map)['lineup'] as List)
          (l as Map)['cardInstanceId'],
      ];
      expect(inXI, isNot(contains('c3')));
      expect(usableCards(s).map((c) => c.instanceId), isNot(contains('c3')));
      expect(listedCards(s).map((c) => c.instanceId), ['c3']);
    });

    test('and pays for it — a listed player draws a better price', () {
      final s = _state();
      final plain = listedPremium(CardInstance.from(((s['grid'] as Map)['cells'] as List)[3]));
      listPlayer(s, 'c3');
      final listed = listedPremium(CardInstance.from(((s['grid'] as Map)['cells'] as List)[3]));
      expect(listed, greaterThan(plain));
    });

    test('never the last usable player', () {
      final s = _state(cards: 1);
      final result = listPlayer(s, 'c0');
      expect(result.ok, isFalse);
      expect(result.reason, 'last_player');
    });

    test('never a borrowed player — not ours to sell', () {
      final s = _state();
      (((s['grid'] as Map)['cells'] as List)[2] as Map)['loanMatchesLeft'] = 4;
      expect(listPlayer(s, 'c2').reason, 'loan_card');
    });

    test('listing twice is not an error', () {
      final s = _state();
      expect(listPlayer(s, 'c3').ok, isTrue);
      expect(listPlayer(s, 'c3').ok, isTrue);
      expect(listedCards(s), hasLength(1));
    });
  });

  group('what a rival offers', () {
    test('never more players than we can actually house', () {
      // The accept path drops any player it cannot place and pays only the cash,
      // so an over-large swap handed over our man and binned one of theirs.
      for (var seed = 0; seed < 80; seed++) {
        seeded.setSeed(seed);
        final s = _state(cards: 30);
        final target = CardInstance.from(((s['grid'] as Map)['cells'] as List)[0]);
        final offer = buildRivalOffer(s, target, 50000);
        expect(
          (offer['incoming'] as List).length,
          lessThanOrEqualTo(1),
          reason: 'seed $seed',
        );
      }
    });

    test('always worth something, whatever the shape', () {
      for (var seed = 0; seed < 40; seed++) {
        seeded.setSeed(seed);
        final s = _state();
        final target = CardInstance.from(((s['grid'] as Map)['cells'] as List)[0]);
        final offer = buildRivalOffer(s, target, 50000);
        expect(offerValue(s, offer), greaterThan(0), reason: 'seed $seed');
      }
    });

    test('a mixed offer is a slight discount for them', () {
      // Which is what makes "cash only" the cleaner deal and gives the two
      // options genuinely different characters.
      var mixedSeen = 0;
      for (var seed = 0; seed < 200 && mixedSeen < 5; seed++) {
        seeded.setSeed(seed);
        final s = _state();
        final target = CardInstance.from(((s['grid'] as Map)['cells'] as List)[0]);
        final offer = buildRivalOffer(s, target, 50000);
        if ((offer['incoming'] as List).isEmpty) continue;
        mixedSeen++;
        expect(offerValue(s, offer), lessThan(50000 * 1.001), reason: 'seed $seed');
      }
      expect(mixedSeen, greaterThan(0), reason: 'no mixed offer in 200 seeds');
    });
  });

  group('who a rival comes in for', () {
    test('never an injured player, or a borrowed one', () {
      final s = _state();
      final cells = (s['grid'] as Map)['cells'] as List;
      for (var i = 0; i < cells.length; i++) {
        (cells[i] as Map)[i.isEven ? 'injured' : 'loanMatchesLeft'] =
            i.isEven ? true : 4;
      }
      for (var seed = 0; seed < 20; seed++) {
        seeded.setSeed(seed);
        expect(pickBidTarget(s), isNull, reason: 'seed $seed');
      }
    });

    test('never below the minimum tier', () {
      final s = _state(tier: 3);
      for (var seed = 0; seed < 20; seed++) {
        seeded.setSeed(seed);
        expect(pickBidTarget(s, minTier: 4), isNull, reason: 'seed $seed');
        expect(pickBidTarget(s, minTier: 3), isNotNull, reason: 'seed $seed');
      }
    });

    test('never one already spoken for', () {
      final s = _state(cards: 2);
      for (var seed = 0; seed < 30; seed++) {
        seeded.setSeed(seed);
        expect(
          pickBidTarget(s, exclude: {'c0'})?.card.instanceId,
          'c1',
          reason: 'seed $seed',
        );
      }
    });
  });

  group('rollDealCard', () {
    test('an elite card usually arrives with a trait, a bronze one rarely', () {
      int withTrait(int tier) {
        var n = 0;
        for (var seed = 0; seed < 300; seed++) {
          seeded.setSeed(seed);
          setMergeRandom(math.Random(seed));
          setTraitRandom(math.Random(seed));
          final def = getPlayersByTier(tier).first;
          if (rollDealCard(def)!.raw['trait'] != null) n++;
        }
        return n;
      }

      expect(withTrait(8), greaterThan(withTrait(1) * 2));
    });

    test('the card that arrives is a real, complete instance', () {
      // Signings used to be a definition id plus a name, so the feed had no
      // artwork and no real ATK/DEF to show — you were buying a rarity label.
      final def = getPlayersByTier(5).first;
      final card = rollDealCard(def)!;
      expect(card.instanceId, isNotEmpty);
      expect(card.definitionId, def.id);
      expect(card.attackRatio, isNotNull);
      expect(card.raw['displayName'], isNotNull);
      expect(card.raw['stats'], isNotNull);
    });
  });

  group('surrenderPlayers', () {
    test('clears the grid cell and the XI slot together', () {
      // Leaving a surrendered player in the lineup would field a card that is no
      // longer ours.
      final s = _state();
      final gone = surrenderPlayers(s, {'players': ['c2', 'c5']});
      expect(gone.map((c) => c.instanceId), ['c2', 'c5']);
      final cells = [
        for (final c in (s['grid'] as Map)['cells'] as List)
          (c as Map?)?['instanceId'],
      ];
      expect(cells, isNot(contains('c2')));
      expect(cells, isNot(contains('c5')));
      final inXI = [
        for (final l in (s['squad'] as Map)['lineup'] as List)
          (l as Map)['cardInstanceId'],
      ];
      expect(inXI, isNot(contains('c2')));
      expect(inXI, isNot(contains('c5')));
    });

    test('skips a player who is not there rather than throwing', () {
      final s = _state();
      expect(surrenderPlayers(s, {'players': ['ghost']}), isEmpty);
      expect(surrenderPlayers(s, null), isEmpty);
      expect(surrenderPlayers(s, {}), isEmpty);
    });
  });
}
