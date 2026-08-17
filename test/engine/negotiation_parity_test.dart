/// Differential test: the Dart negotiation engine against the JS it was ported
/// from.
///
/// The design claim this protects is SYMMETRY. Both sides of a deal speak the
/// same shape — cash, our players, their cards — and both are judged by the same
/// `offerValue`, so a deal that reads as fair is fair with no hidden multiplier
/// on either side. Getting one of the two valuations subtly wrong breaks that
/// claim without breaking anything visible, so both directions are pinned.
///
/// `rollDealCard` mixes both generators — the gender and trait-chance rolls are
/// seeded, the variant, rating spread, ATK/DEF ratio and the trait itself are
/// not — so the unseeded stream is pinned here too. ONE instance feeds
/// `merge_engine` and `trait_engine`, because the JS has one `Math.random`.
///
/// See `tool/dump_negotiation_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/negotiation.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/engine/negotiation_engine.dart';
import 'package:merge_empire_fc/engine/trait_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import '../support/js_math_random.dart';

final Map<String, dynamic> ref = jsonDecode(
  File('test/fixtures/negotiation_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final Map<String, dynamic> refSave = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

final int fixedNow = ref['fixedNow'] as int;

Object? _json(Object? v) => jsonDecode(jsonEncode(v));

List<Map<String, dynamic>> _rows(String key) => [
  for (final r in ref[key] as List) r as Map<String, dynamic>,
];

Map<String, dynamic> _baseState() {
  final s = jsonDecode(jsonEncode(refSave['state'])) as Map<String, dynamic>;
  (s['resources'] as Map)['fanCoins'] = 500000;
  return s;
}

const _pos = [
  'gk', 'def', 'def', 'mid', 'mid', 'mid', 'fwd', 'fwd', 'def', 'mid', 'fwd',
  'mid', 'def',
];

/// A squad with a known spread of tiers, matching the dump script's own.
Map<String, dynamic> _tieredSquad(List<int> tiers) {
  final s = _baseState();
  final cells = (s['grid'] as Map)['cells'] as List;
  for (var i = 0; i < cells.length; i++) {
    if (cells[i] == null || i >= tiers.length) {
      cells[i] = null;
      continue;
    }
    (cells[i] as Map)['definitionId'] = 'player_t${tiers[i]}_${_pos[i]}';
  }
  return s;
}

/// A grid filled right up to the roster cap, which the reference save is nowhere
/// near — it holds 15 cards against a roster of 30.
Map<String, dynamic> _cappedSquad() {
  final s = _baseState();
  final max = getMaxPlayers(s);
  (s['grid'] as Map)['cells'] = [
    for (var i = 0; i < max; i++)
      {
        'instanceId': 'f$i',
        'definitionId': 'player_t${1 + (i % 6)}_${_pos[i % _pos.length]}',
        'seasonsPlayed': 0,
      },
  ];
  final lineup = (s['squad'] as Map)['lineup'] as List;
  for (var i = 0; i < lineup.length; i++) {
    (lineup[i] as Map)['cardInstanceId'] = 'f$i';
  }
  return s;
}

Map<String, dynamic> _squadFor(String label) => switch (label) {
  'room' => _tieredSquad([3, 4, 5, 3, 4, 6, 3]),
  'roomy' => _tieredSquad([3, 4, 5]),
  'capped' => _cappedSquad(),
  _ => throw ArgumentError(label),
};

/// A card map, minus the instance id — that embeds a module counter reflecting
/// how many cards each runtime happened to have built already, which says
/// nothing about the deal. Its shape is asserted separately.
Map<String, dynamic> _withoutId(CardInstance card) {
  final out = Map<String, dynamic>.of(card.raw)..remove('instanceId');
  return jsonDecode(jsonEncode(out)) as Map<String, dynamic>;
}

/// Seeds both streams the way the dump did, and returns the shared unseeded one.
void _seedBoth(int seed, int mathSeed) {
  seeded.setSeed(seed);
  // ONE instance for both, because the JS has one Math.random.
  final rng = JsMathRandom(mathSeed);
  setMergeRandom(rng);
  setTraitRandom(rng);
}

void main() {
  setUp(() => setClock(() => fixedNow));
  tearDown(() {
    resetClock();
    resetMergeRandom();
    resetTraitRandom();
    clearBus();
  });

  group('constants', () {
    test('match the JS', () {
      final c = ref['constants'] as Map<String, dynamic>;
      expect(counterMaxMult, c['COUNTER_MAX_MULT']);
      expect(ceilingJitter, c['CEILING_JITTER']);
      expect(offerMinMult, c['OFFER_MIN_MULT']);
      expect(offerMinFloor, c['OFFER_MIN_FLOOR']);
      expect(offerMinCeil, c['OFFER_MIN_CEIL']);
      expect(rebuttalSplit, c['REBUTTAL_SPLIT']);
      expect(haggleRoundsMax, c['HAGGLE_ROUNDS_MAX']);
      expect(walkAwayMult, c['WALK_AWAY_MULT']);
      expect(counterFloorMult, c['COUNTER_FLOOR_MULT']);
      expect(sellerCounterSplit, c['SELLER_COUNTER_SPLIT']);
      expect(incomingPlayerChance, c['INCOMING_PLAYER_CHANCE']);
      expect(incomingSecondChance, c['INCOMING_SECOND_CHANCE']);
      expect(incomingTierOffset, c['INCOMING_TIER_OFFSET']);
      expect(listedBidPremium, c['LISTED_BID_PREMIUM']);
      expect(listedBidWeight, c['LISTED_BID_WEIGHT']);
      expect(mixedCashCover, c['MIXED_CASH_COVER']);
    });
  });

  group('playerValue', () {
    test('matches the JS across tier, age, sponsor and division', () {
      final rows = _rows('playerValue');
      expect(rows, hasLength(90));
      for (final row in rows) {
        final s = _baseState();
        (s['progression'] as Map)['currentDivision'] = row['division'];
        final card = CardInstance({
          'instanceId': 'x',
          'definitionId': 'player_t${row['tier']}_mid',
          'seasonsPlayed': row['seasons'],
          if (row['sponsored'] == true) 'sponsor': {'multiplier': 1.5},
        });
        expect(
          playerValue(s, card),
          row['value'],
          reason: 't${row['tier']} / ${row['seasons']}s / ${row['division']}',
        );
      }
    });
  });

  group('offerValue', () {
    test('adds cash, our players and their cards on one scale', () {
      final s = _tieredSquad([3, 3, 4, 5, 6, 3, 4, 7, 3, 4, 5, 3, 4]);
      for (final row in _rows('offerValue')) {
        expect(
          offerValue(s, row['offer'] as Map<String, dynamic>?),
          row['value'],
          reason: '${row['offer']}',
        );
      }
    });

    test('breaks an offer down the way the JS does', () {
      final s = _tieredSquad([3, 3, 4, 5, 6, 3, 4, 7, 3, 4, 5, 3, 4]);
      final parts = describeOffer(s, {
        'cash': 1000,
        'players': ['c0', 'nope'],
        'incoming': [
          {
            'instanceId': 'inc',
            'definitionId': 'player_t5_fwd',
            'seasonsPlayed': 0,
          },
        ],
      });
      expect(
        [
          for (final p in parts)
            {
              'kind': p.kind,
              'amount': p.amount,
              'name': p.name,
              'value': p.value,
            },
        ],
        ref['describeOffer'],
      );
    });
  });

  group('the transfer list', () {
    test('matches the JS on every gate and every side effect', () {
      for (final row in _rows('listing')) {
        final label = '${row['label']}';
        final s = switch (label) {
          'plain' => _baseState(),
          'unknown' => _baseState(),
          'alreadyListed' => () {
            final s = _baseState();
            (((s['grid'] as Map)['cells'] as List)[5] as Map)['listed'] = true;
            return s;
          }(),
          'loanCard' => () {
            final s = _baseState();
            (((s['grid'] as Map)['cells'] as List)[5] as Map)['loanMatchesLeft'] =
                4;
            return s;
          }(),
          'lastPlayer' => () {
            final s = _baseState();
            final cells = (s['grid'] as Map)['cells'] as List;
            for (var i = 1; i < cells.length; i++) {
              cells[i] = null;
            }
            return s;
          }(),
          _ => throw ArgumentError(label),
        };

        final result = listPlayer(s, '${row['instanceId']}');
        expect(result.ok, row['ok'], reason: label);
        expect(result.reason, row['reason'], reason: label);
        expect(
          result.card == null
              ? null
              : {
                  'listed': result.card!.raw['listed'],
                  'listedAt': result.card!.raw['listedAt'],
                },
          row['card'],
          reason: label,
        );
        expect(
          _json((s['squad'] as Map)['lineup']),
          row['lineup'],
          reason: '$label — lineup',
        );
        expect(
          usableCards(s).map((c) => c.instanceId).toList(),
          row['usable'],
          reason: '$label — usable',
        );
        expect(
          listedCards(s).map((c) => c.instanceId).toList(),
          row['listedCards'],
          reason: '$label — listed',
        );
      }
    });

    test('unlisting removes the fields rather than nulling them', () {
      // A nulled field still serialises, so it would leave `listed: null` in the
      // save where the JS leaves the key out entirely.
      final want = ref['unlisting'] as Map<String, dynamic>;
      final s = _baseState();
      listPlayer(s, 'c5');
      final card = ((s['grid'] as Map)['cells'] as List)[5] as Map;
      expect({'listed': card['listed'], 'listedAt': card['listedAt']},
          want['before']);

      expect(unlistPlayer(s, 'c5').ok, want['ok']);
      expect(card.containsKey('listed'), want['hasListed']);
      expect(card.containsKey('listedAt'), want['hasListedAt']);

      final unknown = unlistPlayer(s, 'nope');
      expect(unknown.ok, (want['unknown'] as Map)['ok']);
      expect(unknown.reason, (want['unknown'] as Map)['reason']);
    });
  });

  group('rollDealCard', () {
    test('traitChanceForTier matches the JS', () {
      (ref['traitChanceForTier'] as Map<String, dynamic>).forEach((tier, want) {
        expect(
          traitChanceForTier(int.parse(tier)),
          closeTo(want as num, 1e-12),
          reason: 'tier $tier',
        );
      });
    });

    test('rolls the same card the JS rolls, trait and all', () {
      final rows = _rows('rollDealCard');
      expect(rows, hasLength(12));
      for (final row in rows) {
        _seedBoth(row['seed'] as int, row['mathSeed'] as int);
        final def = getPlayersByTier(row['tier'] as int).first;
        expect(def.id, row['defId'], reason: 'the pool moved under the fixture');
        final card = rollDealCard(def)!;
        expect(
          _withoutId(card),
          row['card'],
          reason: 't${row['tier']} / seed ${row['seed']}',
        );
        // The id is dropped from the comparison, so its shape is checked here.
        expect(card.instanceId, startsWith('${def.id}_'));
      }
    });

    test('returns null without a definition', () {
      expect(rollDealCard(null), isNull);
    });
  });

  group('buildRivalOffer', () {
    test('matches the JS, and never offers more than we can house', () {
      final rows = _rows('buildRivalOffer');
      expect(rows, hasLength(48));
      var capped = 0;
      for (final row in rows) {
        _seedBoth(row['seed'] as int, row['mathSeed'] as int);
        final s = _squadFor('${row['label']}');
        expect(getMaxPlayers(s), row['maxPlayers']);
        expect(
          ((s['grid'] as Map)['cells'] as List)
              .whereType<Map<String, dynamic>>()
              .length,
          row['occupied'],
        );

        final target = CardInstance.from(((s['grid'] as Map)['cells'] as List)[2]);
        final offer = buildRivalOffer(s, target, 50000);
        final why = '${row['label']} / seed ${row['seed']}';
        expect(offer['cash'], row['cash'], reason: why);
        expect(
          [
            for (final c in (offer['incoming'] as List).cast<Map<String, dynamic>>())
              (Map<String, dynamic>.of(c)..remove('instanceId')),
          ],
          row['incoming'],
          reason: why,
        );
        expect(offerValue(s, offer), row['value'], reason: why);
        if (row['label'] == 'capped') {
          expect(
            (offer['incoming'] as List).length,
            lessThanOrEqualTo(1),
            reason: 'a full squad has only the outgoing cell to spare — $why',
          );
          capped++;
        }
      }
      expect(capped, 16);
    });

    test('an unknown target is a cash deal', () {
      final want = ref['buildRivalOfferNoDef'] as Map<String, dynamic>;
      _seedBoth(9, 9);
      final s = _tieredSquad([3, 4, 5]);
      final offer = buildRivalOffer(
        s,
        CardInstance({'instanceId': 'x', 'definitionId': 'nope'}),
        1234,
      );
      expect(offer['cash'], want['cash']);
      expect((offer['incoming'] as List).length, want['incoming']);
    });
  });

  group('pickBidTarget', () {
    test('picks the same player the JS picks, under every filter', () {
      final rows = _rows('pickBidTarget');
      expect(rows, hasLength(24));
      for (final row in rows) {
        seeded.setSeed(row['seed'] as int);
        final label = '${row['label']}';
        final s = _tieredSquad([3, 4, 5, 3, 4, 6, 3]);
        final cells = (s['grid'] as Map)['cells'] as List;
        switch (label) {
          case 'injured':
            (cells[5] as Map)['injured'] = true;
          case 'loanee':
            (cells[5] as Map)['loanMatchesLeft'] = 3;
          case 'listed':
            (cells[0] as Map)['listed'] = true;
          case 'sponsored':
            (cells[0] as Map)['sponsor'] = {'multiplier': 1.5};
        }
        final opts = row['opts'] as Map<String, dynamic>;
        final pick = pickBidTarget(
          s,
          exclude: {for (final e in opts['exclude'] as List) e},
          minTier: (opts['minTier'] as num?)?.toInt() ?? 2,
        );
        expect(
          pick?.card.instanceId,
          row['picked'],
          reason: '$label / seed ${row['seed']}',
        );
      }
    });

    test('listing visibly works without becoming the only answer', () {
      // Calibrated, not guessed: with an otherwise equal squad, the listed player
      // is drawn about a third of the time — clearly more than the one-in-ten he
      // would get by chance, and clearly not always.
      final want = ref['listedDraw'] as Map<String, dynamic>;
      seeded.setSeed(4242);
      final s = _tieredSquad(List.filled(10, 4));
      (((s['grid'] as Map)['cells'] as List)[3] as Map)['listed'] = true;
      var hits = 0;
      for (var i = 0; i < (want['runs'] as int); i++) {
        if (pickBidTarget(s)?.card.instanceId == 'c3') hits++;
      }
      expect(hits, want['hits']);
    });

    test('listedPremium matches the JS', () {
      final want = ref['listedPremium'] as Map<String, dynamic>;
      expect(listedPremium(CardInstance({'listed': true})), want['listed']);
      expect(listedPremium(CardInstance({})), want['plain']);
      expect(listedPremium(null), want['nullCard']);
    });
  });

  group('evaluateAsk', () {
    test('matches the JS on every ask against every buyer', () {
      final rows = _rows('evaluateAsk');
      expect(rows, hasLength(98));
      final s = _baseState();
      for (final row in rows) {
        final listing = row['listing'] as Map<String, dynamic>;
        final got = evaluateAsk(s, listing, (row['ask'] as num?));
        final why = '$listing ask=${row['ask']}';
        expect(got.outcome, row['outcome'], reason: why);
        expect(got.price, row['price'], reason: why);
      }
    });
  });

  group('evaluateOurOffer', () {
    test('matches the JS on every offer against every seller', () {
      final rows = _rows('evaluateOurOffer');
      expect(rows, hasLength(63));
      final s = _tieredSquad([3, 4, 5, 3, 4, 6, 3]);
      for (final row in rows) {
        final listing = row['listing'] as Map<String, dynamic>;
        final got = evaluateOurOffer(
          s,
          listing,
          row['offer'] as Map<String, dynamic>?,
        );
        final why = '$listing offer=${row['offer']}';
        expect(got.outcome, row['outcome'], reason: why);
        expect(got.value, row['value'], reason: why);
        expect(got.needed, row['needed'], reason: why);
        expect(got.shortfall, row['shortfall'], reason: why);
        expect(got.counterPrice, row['counterPrice'], reason: why);
      }
    });
  });

  group('surrenderPlayers', () {
    test('hands over the same players and clears the same slots', () {
      for (final row in _rows('surrenderPlayers')) {
        final s = _baseState();
        final gone = surrenderPlayers(s, {'players': row['ids']});
        final why = '${row['label']}';
        expect(gone.map((c) => c.instanceId).toList(), row['gone'], reason: why);
        expect(
          [
            for (final c in (s['grid'] as Map)['cells'] as List)
              (c as Map?)?['instanceId'],
          ],
          row['cells'],
          reason: why,
        );
        expect(
          [
            for (final l in (s['squad'] as Map)['lineup'] as List)
              (l as Map)['cardInstanceId'],
          ],
          row['lineup'],
          reason: why,
        );
      }
    });

    test('a null offer surrenders nobody', () {
      final s = _baseState();
      expect(
        surrenderPlayers(s, null),
        hasLength((ref['surrenderNullOffer'] as Map)['gone']),
      );
    });
  });
}
