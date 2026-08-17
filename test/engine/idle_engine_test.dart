import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/time.dart';

CardInstance _card({
  String definitionId = 'player_t5_fwd',
  bool injured = false,
  bool borrowed = false,
  Map<String, dynamic>? sponsor,
  String? traitId,
  int traitLevel = 1,
  int? loanMatchesLeft,
  int? injuredAt,
  int? injuryDurationMs,
  String instanceId = 'c1',
}) => CardInstance({
  'instanceId': instanceId,
  'definitionId': definitionId,
  if (injured) 'injured': true,
  if (borrowed) 'borrowed': true,
  'sponsor': ?sponsor,
  if (traitId != null) 'trait': {'id': traitId, 'level': traitLevel},
  'loanMatchesLeft': ?loanMatchesLeft,
  'injuredAt': ?injuredAt,
  'injuryDurationMs': ?injuryDurationMs,
});

Map<String, dynamic> _state({
  List<CardInstance?> cards = const [],
  Map<String, dynamic>? clubAssets,
  Map<String, dynamic>? boosts,
  Map<String, dynamic>? prestige,
  int seasonCount = 1,
  num lastSeen = 0,
  Map<String, dynamic>? transferMarket,
}) => {
  'grid': <String, dynamic>{'cells': <dynamic>[for (final c in cards) c?.raw]},
  'clubAssets': clubAssets ?? <String, dynamic>{},
  'boosts': boosts ?? <String, dynamic>{},
  'prestige': prestige ?? <String, dynamic>{},
  'club': <String, dynamic>{},
  'progression': <String, dynamic>{'seasonCount': seasonCount},
  'lastSeen': lastSeen,
  'shop': <String, dynamic>{},
  'transferMarket': ?transferMarket,
  'squad': <String, dynamic>{'formation': '4-3-3', 'lineup': null},
};

Map<String, dynamic> _asset(String cat, int tier) => {
  cat: {'owned': true, 'tier': tier},
};

void main() {
  setUp(resetClock);

  group('cardBaseIncomePerSec', () {
    test('is the definition rate for a plain card', () {
      expect(cardBaseIncomePerSec(_card()), 2.56);
    });

    test('an injured card earns a fifth', () {
      expect(
        cardBaseIncomePerSec(_card(injured: true)),
        closeTo(2.56 * injuryIncomeFactor, 1e-9),
      );
    });

    test('a borrowed card never earns', () {
      // They are not ours; the wage is what they cost.
      expect(cardBaseIncomePerSec(_card(borrowed: true)), 0);
    });

    test('a sponsor multiplies income', () {
      expect(
        cardBaseIncomePerSec(_card(sponsor: {'multiplier': 2.0})),
        closeTo(5.12, 1e-9),
      );
    });

    test('an income trait multiplies income', () {
      // Playmaker III is +85%. The card footer used to ignore this and
      // understate a Playmaker by up to 85%.
      expect(
        cardBaseIncomePerSec(
          _card(definitionId: 'player_t5_mid', traitId: 'playmaker', traitLevel: 3),
        ),
        closeTo(2.5 * 1.85, 1e-9),
      );
    });

    test('injury, sponsor and trait stack multiplicatively', () {
      final income = cardBaseIncomePerSec(
        _card(
          definitionId: 'player_t5_mid',
          injured: true,
          sponsor: {'multiplier': 2.0},
          traitId: 'playmaker',
          traitLevel: 3,
        ),
      );
      expect(income, closeTo(2.5 * 0.2 * 2.0 * 1.85, 1e-9));
    });

    test('an unknown definition or null earns nothing', () {
      expect(cardBaseIncomePerSec(null), 0);
      expect(cardBaseIncomePerSec(CardInstance({'definitionId': 'nope'})), 0);
    });
  });

  group('computeBaseRate', () {
    test('sums the grid', () {
      expect(
        computeBaseRate([_card(), _card(definitionId: 'player_t1_fwd')]),
        closeTo(2.56 + 0.05, 1e-9),
      );
    });

    test('tolerates empty slots', () {
      expect(computeBaseRate([null, _card(), null]), 2.56);
    });

    test('an empty grid earns nothing', () {
      expect(computeBaseRate([]), 0);
    });
  });

  group('merchIncomeMultiplier', () {
    test('is +5% per tier', () {
      expect(merchIncomeMultiplier(0), 1.0);
      expect(merchIncomeMultiplier(4), closeTo(1.20, 1e-9));
    });

    test('caps at +40%', () {
      expect(merchIncomeMultiplier(8), closeTo(1.40, 1e-9));
      expect(merchIncomeMultiplier(20), closeTo(1.40, 1e-9));
    });

    test('a null tier is neutral', () {
      expect(merchIncomeMultiplier(null), 1.0);
    });
  });

  group('computeMultiplier', () {
    test('is neutral with nothing owned', () {
      expect(computeMultiplier({}, {}, {}, {}, 1), 1.0);
    });

    test('applies the Merch tier', () {
      expect(
        computeMultiplier(_asset(AssetCategory.merch, 8), {}, {}, {}, 1),
        closeTo(1.40, 1e-9),
      );
    });

    test('an unowned Merch store counts as tier zero', () {
      expect(
        computeMultiplier(
          {AssetCategory.merch: {'owned': false, 'tier': 8}},
          {}, {}, {}, 1,
        ),
        1.0,
      );
    });

    test('an active income boost doubles', () {
      setClock(() => 1000);
      expect(
        computeMultiplier(
          {},
          {'incomeBoostActive': true, 'incomeBoostEndsAt': 5000},
          {}, {}, 1,
        ),
        Idle.boostMultiplier,
      );
    });

    test('an expired income boost does nothing', () {
      setClock(() => 9000);
      expect(
        computeMultiplier(
          {},
          {'incomeBoostActive': true, 'incomeBoostEndsAt': 5000},
          {}, {}, 1,
        ),
        1.0,
      );
    });

    test('the kit sponsor applies only in its bought-for season', () {
      // Buying mid-season must expire at the season boundary, not 14 matches on.
      expect(computeMultiplier({}, {'kitSponsorSeason': 3}, {}, {}, 3), 1.25);
      expect(computeMultiplier({}, {'kitSponsorSeason': 3}, {}, {}, 4), 1.0);
    });

    test('prestige multiplies when above one', () {
      expect(computeMultiplier({}, {}, {'incomeMultiplier': 1.5}, {}, 1), 1.5);
      expect(computeMultiplier({}, {}, {'incomeMultiplier': 1.0}, {}, 1), 1.0);
    });

    test('VIP doubles while active', () {
      setClock(() => 1000);
      expect(
        computeMultiplier({}, {'vipActive': true, 'vipExpiresAt': 5000}, {}, {}, 1),
        2.0,
      );
    });

    test('trophy polish doubles for its season', () {
      expect(computeMultiplier({}, {'trophyPolishSeason': 2}, {}, {}, 2), 2.0);
      expect(computeMultiplier({}, {'trophyPolishSeason': 2}, {}, {}, 3), 1.0);
    });

    test('every source stacks multiplicatively', () {
      setClock(() => 1000);
      final mult = computeMultiplier(
        _asset(AssetCategory.merch, 8),
        {
          'incomeBoostActive': true,
          'incomeBoostEndsAt': 5000,
          'kitSponsorSeason': 1,
          'trophyPolishSeason': 1,
        },
        {'incomeMultiplier': 1.5},
        {},
        1,
      );
      expect(mult, closeTo(1.40 * 2.0 * 1.25 * 1.5 * 2.0, 1e-9));
    });
  });

  group('incomeBarCycleSec', () {
    test('a zero or corrupt rate parks the bar at its slowest', () {
      // Rather than dividing by zero into an infinitely fast animation.
      expect(incomeBarCycleSec(0), IncomeBar.maxCycleSec);
      expect(incomeBarCycleSec(-5), IncomeBar.maxCycleSec);
      expect(incomeBarCycleSec(double.nan), IncomeBar.maxCycleSec);
      expect(incomeBarCycleSec(double.infinity), IncomeBar.maxCycleSec);
    });

    test('the slowest rate maps to the longest cycle', () {
      expect(incomeBarCycleSec(IncomeBar.loRate), closeTo(IncomeBar.maxCycleSec, 1e-9));
    });

    test('the fastest rate maps to the shortest cycle', () {
      expect(incomeBarCycleSec(IncomeBar.hiRate), closeTo(IncomeBar.minCycleSec, 1e-9));
    });

    test('rates outside the band clamp to the ends', () {
      expect(incomeBarCycleSec(0.0001), closeTo(IncomeBar.maxCycleSec, 1e-9));
      expect(incomeBarCycleSec(999999), closeTo(IncomeBar.minCycleSec, 1e-9));
    });

    test('a richer card is always faster', () {
      var prev = double.infinity;
      for (final rate in [0.05, 0.5, 5.0, 50.0, 500.0]) {
        final cycle = incomeBarCycleSec(rate);
        expect(cycle, lessThan(prev));
        prev = cycle;
      }
    });

    test('the low-end floor still spreads richer cards apart', () {
      final slow = incomeBarCycleSec(1, IncomeBar.lowEndMinCycleSec);
      final fast = incomeBarCycleSec(100, IncomeBar.lowEndMinCycleSec);
      expect(fast, lessThan(slow));
      expect(fast, greaterThanOrEqualTo(IncomeBar.lowEndMinCycleSec - 1e-9));
    });
  });

  group('computeMatchRevenueMultiplier', () {
    test('the Stadium compounds per tier', () {
      expect(
        computeMatchRevenueMultiplier(_asset(AssetCategory.stadium, 3), {}, 1),
        closeTo(1.331, 1e-9),
      );
    });

    test('the TV deal applies only in its season', () {
      expect(computeMatchRevenueMultiplier({}, {'matchRevBoostSeason': 2}, 2), 1.5);
      expect(computeMatchRevenueMultiplier({}, {'matchRevBoostSeason': 2}, 3), 1.0);
    });

    test('trophy polish doubles match revenue too', () {
      // It doubles ALL coin income, mirroring the idle multiplier.
      expect(computeMatchRevenueMultiplier({}, {'trophyPolishSeason': 1}, 1), 2.0);
    });

    test('squad traits are multiplicative with the club stack', () {
      // A Commanding keeper is worth more once the Stadium is built.
      final bare = computeMatchRevenueMultiplier({}, {}, 1, 0.2);
      final built = computeMatchRevenueMultiplier(
        _asset(AssetCategory.stadium, 4), {}, 1, 0.2,
      );
      expect(bare, closeTo(1.2, 1e-9));
      expect(built, closeTo(1.2 * powInt(1.10, 4), 1e-9));
    });

    test('a zero trait bonus changes nothing', () {
      expect(computeMatchRevenueMultiplier({}, {}, 1), 1.0);
    });
  });

  group('loan wages', () {
    test('a non-loanee costs nothing', () {
      expect(loanWagePerSec(_state(), _card()), 0);
    });

    test('a loanee is charged off the definition, not the card', () {
      // A borrowed card's own income is zero, so a share of what he earns would
      // always be nothing.
      final card = _card(loanMatchesLeft: 5, borrowed: true);
      expect(cardBaseIncomePerSec(card), 0);
      expect(
        loanWagePerSec(_state(), card),
        closeTo(2.56 * loanWageShare, 1e-9),
      );
    });

    test('the wage scales with the club multiplier', () {
      final state = _state(clubAssets: _asset(AssetCategory.merch, 8));
      expect(
        loanWagePerSec(state, _card(loanMatchesLeft: 5)),
        closeTo(2.56 * 1.40 * loanWageShare, 1e-9),
      );
    });

    test('totals across the grid', () {
      final state = _state(
        cards: [
          _card(loanMatchesLeft: 5, instanceId: 'a'),
          _card(loanMatchesLeft: 5, instanceId: 'b'),
          _card(instanceId: 'c'),
        ],
      );
      expect(totalLoanWagePerSec(state), closeTo(2 * 2.56 * loanWageShare, 1e-9));
    });

    test('net income floors at zero — wages never eat the balance', () {
      // An idle game that takes coins off a player who is not playing is a
      // punishment they cannot see coming.
      final state = _state(
        cards: [_card(loanMatchesLeft: 5, borrowed: true, instanceId: 'a')],
      );
      expect(grossIncomePerSec(state), 0);
      expect(totalLoanWagePerSec(state), greaterThan(0));
      expect(netIncomePerSec(state), 0);
    });

    test('flags an unaffordable wage bill', () {
      final broke = _state(
        cards: [_card(loanMatchesLeft: 5, borrowed: true, instanceId: 'a')],
      );
      expect(loanWagesUnaffordable(broke), isTrue);

      final solvent = _state(
        cards: [
          _card(loanMatchesLeft: 5, borrowed: true, instanceId: 'a'),
          _card(definitionId: 'player_t8_fwd', instanceId: 'b'),
        ],
      );
      expect(loanWagesUnaffordable(solvent), isFalse);
    });
  });

  group('computeIncomeDelta', () {
    test('credits the net rate over the elapsed time', () {
      final state = _state(cards: [_card()]);
      expect(computeIncomeDelta(state, 1000), closeTo(2.56, 1e-9));
      expect(computeIncomeDelta(state, 10000), closeTo(25.6, 1e-9));
    });

    test('an empty grid credits nothing', () {
      expect(computeIncomeDelta(_state(), 10000), 0);
    });
  });

  group('processOfflineEarnings', () {
    test('earns a share of the live rate', () {
      setClock(() => 60000);
      final state = _state(cards: [_card(definitionId: 'player_t8_fwd')], lastSeen: 0);
      final result = processOfflineEarnings(state);

      expect(result.offlineMs, 60000);
      // 41/sec * 60s * 5% = 123, rounded to tens.
      expect(result.earned, 120);
    });

    test('caps at the offline ceiling', () {
      setClock(() => Idle.maxOfflineMs * 5);
      final state = _state(cards: [_card()], lastSeen: 0);
      expect(processOfflineEarnings(state).offlineMs, Idle.maxOfflineMs);
    });

    test('earns nothing with no players', () {
      setClock(() => 60000);
      final result = processOfflineEarnings(_state(lastSeen: 0));
      expect(result.earned, 0);
      expect(result.offlineMs, 60000);
    });

    test('earns nothing when no time has passed', () {
      setClock(() => 1000);
      expect(processOfflineEarnings(_state(lastSeen: 1000)).earned, 0);
    });

    test('rounds small payouts to whole coins', () {
      setClock(() => 1000);
      final state = _state(cards: [_card(definitionId: 'player_t1_fwd')], lastSeen: 0);
      expect(processOfflineEarnings(state).earned, isA<int>());
    });

    test('advances offer cooldowns so they do not fire on open', () {
      // Without this, after any idle longer than the cooldown the offers fire
      // the moment the game opens.
      setClock(() => 100000);
      final tm = <String, dynamic>{'lastOfferAt': 1000, 'lastSponsorAt': 2000};
      final state = _state(cards: [_card()], lastSeen: 0, transferMarket: tm);

      processOfflineEarnings(state);
      expect(tm['lastOfferAt'], 100000);
      expect(tm['lastSponsorAt'], 100000);
    });

    test('never advances a cooldown past now', () {
      setClock(() => 5000);
      final tm = <String, dynamic>{'lastOfferAt': 4000};
      final state = _state(cards: [_card()], lastSeen: 0, transferMarket: tm);
      processOfflineEarnings(state);
      expect(tm['lastOfferAt'], 5000);
    });
  });

  group('expireBoosts', () {
    test('clears an elapsed income boost', () {
      setClock(() => 9000);
      final state = _state(
        boosts: {'incomeBoostActive': true, 'incomeBoostEndsAt': 5000},
      );
      expireBoosts(state);
      expect((state['boosts'] as Map)['incomeBoostActive'], isFalse);
      expect((state['boosts'] as Map)['incomeBoostEndsAt'], 0);
    });

    test('leaves a live boost alone', () {
      setClock(() => 1000);
      final state = _state(
        boosts: {'incomeBoostActive': true, 'incomeBoostEndsAt': 5000},
      );
      expireBoosts(state);
      expect((state['boosts'] as Map)['incomeBoostActive'], isTrue);
    });

    test('clears an elapsed VIP pass on both records', () {
      setClock(() => 9000);
      final state = _state(boosts: {'vipActive': true, 'vipExpiresAt': 5000});
      expireBoosts(state);
      expect((state['boosts'] as Map)['vipActive'], isFalse);
      expect((state['shop'] as Map)['vipExpiresAt'], 0);
    });
  });

  group('asset-driven helpers', () {
    test('mini-game cooldown follows Training Ground', () {
      expect(getMiniGameCooldownMult(_state()), 1.0);
      expect(
        getMiniGameCooldownMult(_state(clubAssets: _asset(AssetCategory.training, 8))),
        closeTo(0.6, 1e-9),
      );
    });

    test('mini-game payout follows Media Centre alone', () {
      expect(
        getMiniGameCoinMult(_state(clubAssets: _asset(AssetCategory.media, 8))),
        closeTo(2.52, 1e-9),
      );
      // Training Ground must NOT stack a second multiplier onto the same number.
      expect(
        getMiniGameCoinMult(_state(clubAssets: _asset(AssetCategory.training, 8))),
        1.0,
      );
    });

    test('the roster grows by one per Academy tier and nothing else', () {
      expect(getMaxPlayers(_state()), Grid.maxPlayers);
      expect(
        getMaxPlayers(_state(clubAssets: _asset(AssetCategory.academy, 8))),
        Grid.maxPlayers + 8,
      );
    });

    test('the roster never exceeds what the grid can hold', () {
      expect(
        getMaxPlayers(_state(clubAssets: _asset(AssetCategory.academy, 8))),
        lessThanOrEqualTo(Grid.totalCells),
      );
    });

    test('injury recovery speeds up with Sponsor tier, to a floor', () {
      expect(getInjuryRecoveryMult(_state()), 1.0);
      expect(
        getInjuryRecoveryMult(_state(clubAssets: _asset(AssetCategory.sponsor, 4))),
        closeTo(0.8, 1e-9),
      );
      expect(
        getInjuryRecoveryMult(_state(clubAssets: _asset(AssetCategory.sponsor, 8))),
        0.60,
      );
    });
  });

  group('injury duration and recovery', () {
    test('defaults to the base duration', () {
      expect(getEffectiveInjuryDuration(_state(), _card()), injuryDurationMs);
    });

    test('the Sponsor asset shortens it', () {
      expect(
        getEffectiveInjuryDuration(
          _state(clubAssets: _asset(AssetCategory.sponsor, 8)),
          _card(),
        ),
        closeTo(injuryDurationMs * 0.60, 1e-6),
      );
    });

    test('a recovery trait shortens it further', () {
      final plain = getEffectiveInjuryDuration(_state(), _card());
      final quick = getEffectiveInjuryDuration(
        _state(),
        _card(traitId: 'veteran', traitLevel: 3),
      );
      expect(quick, lessThan(plain));
    });

    test('stacked recovery can never make healing instant', () {
      final duration = getEffectiveInjuryDuration(
        _state(clubAssets: _asset(AssetCategory.sponsor, 8)),
        _card(definitionId: 'player_t5_fwd', traitId: 'speedster', traitLevel: 3),
      );
      expect(duration, greaterThan(injuryDurationMs * 0.25 * 0.60 - 1));
    });

    test('a per-card duration overrides the default', () {
      expect(
        getEffectiveInjuryDuration(_state(), _card(injuryDurationMs: 1000)),
        1000,
      );
    });

    test('heals a card whose injury has elapsed', () {
      setClock(() => injuryDurationMs * 2);
      final card = _card(injured: true, injuredAt: 0);
      final state = _state(cards: [card]);

      expect(processInjuryRecovery(state), isTrue);
      expect(card.injured, isFalse);
      expect(card.raw['injuredAt'], isNull);
    });

    test('leaves a card still injured', () {
      setClock(() => 1000);
      final card = _card(injured: true, injuredAt: 0);
      expect(processInjuryRecovery(_state(cards: [card])), isFalse);
      expect(card.injured, isTrue);
    });

    test('refills the XI once someone heals', () {
      // The injury vacated its slot and nothing else refills it, so without
      // this the team keeps kicking off a man short.
      setClock(() => injuryDurationMs * 2);
      final card = _card(injured: true, injuredAt: 0);
      final state = _state(cards: [card]);
      (state['squad'] as Map)['lineup'] = <dynamic>[
        for (var i = 0; i < 11; i++)
          {'slotId': 's$i', 'slotPosition': 'MID', 'cardInstanceId': null},
      ];

      processInjuryRecovery(state);
      final lineup = (state['squad'] as Map)['lineup'] as List;
      expect(
        lineup.any((s) => (s as Map)['cardInstanceId'] == 'c1'),
        isTrue,
      );
    });

    test('does not refill during a match — that would be an auto-sub', () {
      setClock(() => injuryDurationMs * 2);
      final card = _card(injured: true, injuredAt: 0);
      final state = _state(cards: [card]);
      (state['squad'] as Map)['lineup'] = <dynamic>[
        for (var i = 0; i < 11; i++)
          {'slotId': 's$i', 'slotPosition': 'MID', 'cardInstanceId': null},
      ];

      processInjuryRecovery(state, refillLineup: false);
      final lineup = (state['squad'] as Map)['lineup'] as List;
      expect(
        lineup.every((s) => (s as Map)['cardInstanceId'] == null),
        isTrue,
      );
    });
  });
}

/// Local pow helper so the expectation reads clearly.
double powInt(double base, int exp) {
  var out = 1.0;
  for (var i = 0; i < exp; i++) {
    out *= base;
  }
  return out;
}
