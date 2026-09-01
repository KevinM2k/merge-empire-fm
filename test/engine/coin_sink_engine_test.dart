import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/coin_sinks.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/coin_sink_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/engine/income_breakdown.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> _card(String id, {int seasonsPlayed = 0, String? defId}) => {
  'instanceId': id,
  'definitionId': defId ?? 'player_t3_mid',
  'seasonsPlayed': seasonsPlayed,
};

Map<String, dynamic> _state({
  String division = 'regional_league',
  num coins = 10000000,
  List<dynamic>? cells,
  int slots = 12,
  List<dynamic>? lineup,
  int seasonCount = 1,
  int? trophyPolishUntil,
}) {
  final grid = <dynamic>[...?cells];
  while (grid.length < slots) {
    grid.add(null);
  }
  return {
    'resources': <String, dynamic>{'fanCoins': coins},
    'progression': <String, dynamic>{
      'currentDivision': division,
      'seasonCount': seasonCount,
    },
    'grid': <String, dynamic>{'cells': grid},
    'squad': <String, dynamic>{'lineup': lineup, 'formation': '4-4-2'},
    'clubAssets': defaultClubAssets(),
    'boosts': <String, dynamic>{'trophyPolishUntil': ?trophyPolishUntil},
    'club': <String, dynamic>{},
  };
}

void main() {
  setUp(() => seeded.setSeed(1234));
  tearDown(clearBus);

  /// **IT IS HALF AN HOUR NOW, NOT A SEASON.**
  ///
  /// Stamped with the season it was bought in, what eight gems bought depended
  /// entirely on WHEN in the season they were spent: minutes near the rollover,
  /// hours at the start, and nothing on the tile said which. Asked for from the
  /// couch, and the spec was changed with it.
  group('the trophy polish', () {
    setUp(() => setClock(() => 1000000));
    tearDown(resetClock);

    test('doubles while its window is open', () {
      final state = _state(trophyPolishUntil: 1000000 + trophyPolishMs);
      expect(trophyPolishMultiplier(state), 2.0);
      expect(isTrophyPolishActive(state), isTrue);
      expect(trophyPolishLeftMs(state), trophyPolishMs);
    });

    test('and it runs for THIRTY MINUTES', () {
      expect(trophyPolishMs, 30 * 60 * 1000);
    });

    test('expires on the clock, whatever season it is', () {
      final spent = _state(seasonCount: 4, trophyPolishUntil: 999999);
      expect(trophyPolishMultiplier(spent), 1.0);
      expect(isTrophyPolishActive(spent), isFalse);
      expect(trophyPolishLeftMs(spent), 0);
      // And a season rollover does not touch a window that is still open, which
      // is the whole change: it used to be the only thing that ended it.
      final live = _state(seasonCount: 99, trophyPolishUntil: 1000001);
      expect(trophyPolishMultiplier(live), 2.0);
    });

    test('a save with none is unaffected', () {
      expect(trophyPolishMultiplier(_state()), 1.0);
      expect(trophyPolishMultiplier(null), 1.0);
    });

    test("an old save's permanent polish level is ignored", () {
      // The permanent form was retired to take out a
      // pay-for-permanent-advantage.
      final state = _state();
      (state['boosts'] as Map<String, dynamic>)['polishLevel'] = 5;
      expect(trophyPolishMultiplier(state), 1.0);
    });

    test("and so is an old save's SEASON stamp", () {
      // A save mid-flight when this changed carries `trophyPolishSeason` and no
      // deadline. It simply has no polish — at most half an hour of a buff it
      // was going to lose at the next rollover anyway, and the alternative is
      // reading a season number as a timestamp.
      final state = _state(seasonCount: 4);
      (state['boosts'] as Map<String, dynamic>)['trophyPolishSeason'] = 4;
      expect(trophyPolishMultiplier(state), 1.0);
      expect(gemItemBlocked(state, 'trophy_polish_gem'), isNot('already_held'));
    });

    test('is ONE rule, and everything that pays it out reads it', () {
      // It had been written out five times — twice in `idle_engine`, once in
      // `income_breakdown`, once in `gem_engine`'s shop guard and once here,
      // where the only copy with a name was the one nothing called. This pins
      // the four surviving readers against it rather than against the number 2,
      // because a bonus that changes size is exactly when five copies would be
      // found to have drifted.
      final until = 1000000 + trophyPolishMs;
      final boosts = <String, dynamic>{'trophyPolishUntil': until};
      final live = trophyPolishMultiplierFor(boosts);
      expect(live, greaterThan(1));

      // Idle income, and match revenue, which mirrors it.
      expect(computeMultiplier({}, boosts, {}, {}, 4), live);
      expect(computeMatchRevenueMultiplier({}, boosts, 4), live);

      // The books say what the multiplier is doing, and the row has to carry
      // the same figure or the list stops multiplying out to the total.
      final polish = incomeBreakdown(
        _state(seasonCount: 4, trophyPolishUntil: until),
      ).factors.where((f) => f.key == 'hud.income.trophy_polish');
      expect(polish, hasLength(1));
      expect(polish.first.x, live);

      // And the shop's "already active" is the same question.
      expect(
        gemItemBlocked(
          _state(seasonCount: 4, trophyPolishUntil: until),
          'trophy_polish_gem',
        ),
        'already_held',
      );
    });

    test('a save with no season is no longer a special case at all', () {
      // The five copies used to disagree here — four read a missing
      // `seasonCount` as no match and `gem_engine`'s guard read it as season
      // one, so the shop could refuse to sell a buff nothing was applying. The
      // season is not in the rule any more, so the question cannot be asked.
      final orphan = _state(trophyPolishUntil: 1000000 + trophyPolishMs);
      (orphan['progression'] as Map<String, dynamic>).remove('seasonCount');
      expect(trophyPolishMultiplier(orphan), 2.0);
      expect(gemItemBlocked(orphan, 'trophy_polish_gem'), 'already_held');
    });
  });

  group('unlocking', () {
    test('a sink is offered from its own division upward', () {
      for (final sink in coinSinks) {
        for (var d = 0; d < divisions.length; d++) {
          expect(
            isUnlocked(_state(division: divisions[d].id), sink.id),
            d >= sink.unlockDiv,
            reason: '${sink.id} at ${divisions[d].id}',
          );
        }
      }
    });

    test('an unknown sink is never unlocked', () {
      expect(isUnlocked(_state(), 'nonsense'), isFalse);
    });

    test('an unknown division falls back to the bottom of the ladder', () {
      final state = _state(division: 'retired_league');
      expect(isUnlocked(state, 'lucky_pack'), isTrue);
      expect(isUnlocked(state, 'loyalty_bonus'), isFalse);
    });
  });

  group('the draw pools', () {
    test('the Youth Academy floor rises with the ladder', () {
      final low = youthAcademyPool(0)
          .map((e) => getPlayerDef(e.item)!.tier)
          .reduce((a, b) => a < b ? a : b);
      final high = youthAcademyPool(6)
          .map((e) => getPlayerDef(e.item)!.tier)
          .reduce((a, b) => a < b ? a : b);
      expect(high, greaterThan(low));
    });

    test('it never draws above the craftable ceiling', () {
      for (var d = 0; d < divisions.length; d++) {
        for (final e in youthAcademyPool(d)) {
          expect(getPlayerDef(e.item)!.tier, lessThanOrEqualTo(8), reason: '$d');
        }
      }
    });

    test('every entry carries a positive weight', () {
      for (var d = 0; d < divisions.length; d++) {
        for (final e in youthAcademyPool(d)) {
          expect(e.weight, greaterThan(0), reason: '$d ${e.item}');
        }
      }
    });

    test('the Lucky Pack is bronze at the bottom and silver above', () {
      expect(luckyPackPool(0), same(bronzePool));
      expect(luckyPackPool(1), same(bronzePool));
      expect(luckyPackPool(2), same(silverPool));
      expect(luckyPackPool(6), same(silverPool));
    });

    test('the Academy draws ABOVE what merging can build', () {
      // Which is why the discovery reachability check has to include it.
      final amateur = divisions.indexWhere((d) => d.id == 'amateur_cup');
      final mergeCap = divisions[amateur].maxPlayerTier;
      final best = youthAcademyPool(amateur)
          .map((e) => getPlayerDef(e.item)!.tier)
          .reduce((a, b) => a > b ? a : b);
      expect(best, greaterThan(mergeCap));
    });
  });

  group('peekCost', () {
    test('answers without charging', () {
      final state = _state();
      final before = state['resources']['fanCoins'];
      expect(peekCost(state, 'lucky_pack'), greaterThan(0));
      expect(state['resources']['fanCoins'], before);
    });

    test('an unknown sink is free', () {
      expect(peekCost(_state(), 'nonsense'), 0);
    });

    test('the loyalty bonus is priced on the card it targets', () {
      final state = _state(cells: [
        _card('cheap', defId: 'player_t1_gk'),
        _card('dear', defId: 'player_t7_fwd'),
      ]);
      expect(
        peekCost(state, 'loyalty_bonus', cardInstanceId: 'dear'),
        greaterThan(peekCost(state, 'loyalty_bonus', cardInstanceId: 'cheap')),
      );
    });

    test('a sink costs more the higher you climb', () {
      expect(
        peekCost(_state(division: 'champions_cup'), 'lucky_pack'),
        greaterThan(peekCost(_state(division: 'sunday_league'), 'lucky_pack')),
      );
    });
  });

  group('purchaseCoinSink', () {
    test('refuses an unknown sink', () {
      expect(purchaseCoinSink(_state(), 'nonsense').reason, 'unknown_sink');
    });

    test('refuses one the division has not unlocked', () {
      final state = _state(division: 'sunday_league');
      expect(purchaseCoinSink(state, 'loyalty_bonus').reason, 'locked');
    });

    test('refuses an empty wallet and says what it would have cost', () {
      final state = _state(coins: 0);
      final result = purchaseCoinSink(state, 'lucky_pack');
      expect(result.reason, 'insufficient_coins');
      expect(result.cost, greaterThan(0));
      expect(state['resources']['fanCoins'], 0);
    });

    test('the kit redesign needs a colour', () {
      final state = _state();
      expect(purchaseCoinSink(state, 'kit_redesign').reason, 'no_color');
    });

    test('and applies it when given one', () {
      final state = _state();
      final result = purchaseCoinSink(state, 'kit_redesign', color: '#ff0000');
      expect(result.ok, isTrue);
      expect(state['club']['kitPrimaryColor'], '#ff0000');
    });

    test('the loyalty bonus takes two seasons off a card', () {
      final state = _state(cells: [_card('vet', seasonsPlayed: 9)]);
      final result = purchaseCoinSink(
        state,
        'loyalty_bonus',
        cardInstanceId: 'vet',
      );
      expect(result.ok, isTrue);
      expect(result.seasonsReduced, 2);
      expect((state['grid']['cells'] as List)[0]['seasonsPlayed'], 7);
    });

    test('and never below zero', () {
      final state = _state(cells: [_card('rookie', seasonsPlayed: 1)]);
      final result = purchaseCoinSink(
        state,
        'loyalty_bonus',
        cardInstanceId: 'rookie',
      );
      expect(result.seasonsReduced, 1);
      expect((state['grid']['cells'] as List)[0]['seasonsPlayed'], 0);
    });

    test('with no card named it takes the oldest', () {
      final state = _state(cells: [
        _card('young', seasonsPlayed: 1),
        _card('old', seasonsPlayed: 8),
      ]);
      purchaseCoinSink(state, 'loyalty_bonus');
      expect((state['grid']['cells'] as List)[1]['seasonsPlayed'], 6);
      expect((state['grid']['cells'] as List)[0]['seasonsPlayed'], 1);
    });

    test('with nobody at the club it refuses', () {
      expect(
        purchaseCoinSink(_state(), 'loyalty_bonus').reason,
        'no_target',
      );
    });

    test('the Youth Academy places a card and charges for it', () {
      final state = _state(division: 'elite_league');
      final before = state['resources']['fanCoins'] as num;
      final result = purchaseCoinSink(state, 'youth_academy');
      expect(result.ok, isTrue);
      expect(result.cardIdx, isNotNull);
      expect((state['grid']['cells'] as List)[result.cardIdx!], isNotNull);
      expect(state['resources']['fanCoins'], lessThan(before));
    });

    test('a full grid refunds rather than charging for nothing', () {
      final state = _state(
        cells: [for (var i = 0; i < 12; i++) _card('c$i')],
        slots: 12,
      );
      final before = state['resources']['fanCoins'];
      final result = purchaseCoinSink(state, 'lucky_pack');
      expect(result.ok, isFalse);
      expect(result.reason, 'grid_full');
      expect(state['resources']['fanCoins'], before);
    });

    test('a new card slots straight into an empty place in the XI', () {
      final state = _state(
        division: 'elite_league',
        lineup: [
          for (var i = 0; i < 11; i++)
            <String, dynamic>{
              'slotId': 's$i',
              'slotPosition': i == 0 ? 'GK' : 'MID',
              'cardInstanceId': null,
            },
        ],
      );
      purchaseCoinSink(state, 'youth_academy');
      final filled = (state['squad']['lineup'] as List)
          .where((s) => (s as Map)['cardInstanceId'] != null)
          .length;
      expect(filled, 1);
    });

    test('a save with no lineup is left alone', () {
      final state = _state(division: 'elite_league');
      expect(purchaseCoinSink(state, 'youth_academy').ok, isTrue);
      expect(state['squad']['lineup'], isNull);
    });

    test('announces the purchase and the new balance', () {
      final state = _state();
      Object? coins;
      Object? purchase;
      on('coins:updated', (v) => coins = v);
      on('coinSink:purchased', (v) => purchase = v);
      purchaseCoinSink(state, 'lucky_pack');
      expect(coins, state['resources']['fanCoins']);
      expect(purchase, isNotNull);
    });

    test('is deterministic for a given seed', () {
      seeded.setSeed(77);
      final a = _state(division: 'elite_league');
      purchaseCoinSink(a, 'youth_academy');
      seeded.setSeed(77);
      final b = _state(division: 'elite_league');
      purchaseCoinSink(b, 'youth_academy');
      expect(
        (a['grid']['cells'] as List).map((c) => (c as Map?)?['definitionId']),
        (b['grid']['cells'] as List).map((c) => (c as Map?)?['definitionId']),
      );
    });
  });
}
