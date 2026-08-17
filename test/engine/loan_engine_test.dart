import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/loans.dart';
import 'package:merge_empire_fc/engine/loan_engine.dart';
import 'package:merge_empire_fc/engine/merge_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> _card(
  String id, {
  String definitionId = 'player_t5_mid',
  int? loanMatchesLeft,
  bool borrowed = false,
  bool injured = false,
  bool listed = false,
  Map<String, dynamic>? loanedOut,
  num? loanWage,
  String? loanFrom,
  int seasonsPlayed = 0,
}) => {
  'instanceId': id,
  'definitionId': definitionId,
  'seasonsPlayed': seasonsPlayed,
  if (borrowed) 'borrowed': true,
  if (injured) 'injured': true,
  if (listed) 'listed': true,
  'loanMatchesLeft': ?loanMatchesLeft,
  'loanedOut': ?loanedOut,
  'loanWage': ?loanWage,
  'loanFrom': ?loanFrom,
};

Map<String, dynamic> _state({
  List<Map<String, dynamic>?> cards = const [],
  int slots = 12,
  num coins = 100000,
  String division = 'regional_league',
  List<dynamic>? lineup,
}) {
  final cells = <dynamic>[...cards];
  while (cells.length < slots) {
    cells.add(null);
  }
  return {
    'grid': <String, dynamic>{'cells': cells},
    'clubAssets': <String, dynamic>{},
    'boosts': <String, dynamic>{},
    'prestige': <String, dynamic>{},
    'club': <String, dynamic>{},
    'resources': <String, dynamic>{'fanCoins': coins},
    'progression': <String, dynamic>{
      'currentDivision': division,
      'seasonCount': 1,
    },
    'squad': <String, dynamic>{'formation': '4-3-3', 'lineup': lineup},
  };
}

void main() {
  setUp(() {
    resetBus();
    resetClock();
    resetMergeRandom();
    resetInstanceCounter();
    seeded.setSeed(12345);
  });

  group('isLoan', () {
    test('a real loan is marked by its match counter', () {
      expect(isLoan(CardInstance(_card('a', loanMatchesLeft: 5))), isTrue);
    });

    test('a tutorial borrowed card is NOT a loan', () {
      // The tutorial drops these and removes them itself — no wages, no
      // countdown, no early departure.
      expect(isLoan(CardInstance(_card('a', borrowed: true))), isFalse);
    });

    test('an ordinary card is not a loan', () {
      expect(isLoan(CardInstance(_card('a'))), isFalse);
      expect(isLoan(null), isFalse);
    });
  });

  group('pricing', () {
    test('a fee and wage scale with the division', () {
      final low = _state(division: 'sunday_league');
      final high = _state(division: 'champions_cup');
      expect(loanFee(high), greaterThan(loanFee(low)));
      expect(loanWage(high), greaterThan(loanWage(low)));
    });

    test('a wage is comfortably covered by a win but bleeds on a loss', () {
      // Win pays 1.00x the base, loss 0.10x.
      final state = _state();
      final matchBase = 600; // regional_league
      expect(loanWage(state), lessThan(matchBase));
      expect(loanWage(state), greaterThan(matchBase * 0.10));
    });

    test('never prices below one coin', () {
      expect(loanFee(_state(division: 'sunday_league')), greaterThanOrEqualTo(1));
      expect(loanWage(_state(division: 'sunday_league')), greaterThanOrEqualTo(1));
    });
  });

  group('loanTierFor', () {
    test('draws one tier above the division ceiling', () {
      // The appeal: a card your league cannot otherwise produce.
      expect(loanTierFor(_state(division: 'sunday_league')), 3);
      expect(loanTierFor(_state(division: 'regional_league')), 5);
    });

    test('never reaches T9 — it is scout-only and uncraftable', () {
      expect(loanTierFor(_state(division: 'champions_cup')), maxLoanTier);
      expect(maxLoanTier, 8);
    });

    test('picks a definition at that tier', () {
      final def = pickLoanee(_state(division: 'regional_league'));
      expect(def, isNotNull);
      expect(def!.tier, 5);
    });
  });

  group('canLoan', () {
    test('allows a loan with room and none active', () {
      expect(canLoan(_state()).ok, isTrue);
    });

    test('refuses past the simultaneous cap', () {
      final state = _state(
        cards: [
          for (var i = 0; i < maxActiveLoans; i++)
            _card('l$i', loanMatchesLeft: 5),
        ],
      );
      final gate = canLoan(state);
      expect(gate.ok, isFalse);
      expect(gate.reason, 'max_loans');
    });

    test('refuses with a full grid', () {
      final state = _state(
        cards: [for (var i = 0; i < 12; i++) _card('c$i')],
        slots: 12,
      );
      expect(canLoan(state).reason, 'squad_full');
    });
  });

  group('grantLoan', () {
    test('places the loanee and charges the fee', () {
      final state = _state(coins: 10000);
      final before = (state['resources'] as Map)['fanCoins'] as num;

      final r = grantLoan(state, 'player_t5_fwd');
      expect(r.ok, isTrue);
      expect(r.card!.raw['borrowed'], isTrue);
      expect(r.card!.raw['loanMatchesLeft'], loanMatches);
      expect(r.card!.raw['loanTotalMatches'], loanMatches);
      expect((state['resources'] as Map)['fanCoins'], before - r.fee!);
    });

    test('refuses without the fee', () {
      final r = grantLoan(_state(coins: 1), 'player_t5_fwd');
      expect(r.ok, isFalse);
      expect(r.reason, 'not_enough_coins');
    });

    test('refuses an unknown definition', () {
      expect(grantLoan(_state(), 'nope').reason, 'unknown_definition');
    });

    test('records who lent the player', () {
      final r = grantLoan(_state(), 'player_t5_fwd', fromTeam: 'Lender FC');
      expect(r.card!.raw['loanFrom'], 'Lender FC');
    });

    test('announces the arrival', () {
      var fired = false;
      on('loan:granted', (_) => fired = true);
      grantLoan(_state(), 'player_t5_fwd');
      expect(fired, isTrue);
    });
  });

  group('settleLoanMatch', () {
    test('burns a game off every loan, started or not', () {
      // Counting only appearances would let benching freeze a spell, turning a
      // rental into a hoard.
      final state = _state(
        cards: [
          _card('a', loanMatchesLeft: 5),
          _card('b', loanMatchesLeft: 3),
        ],
      );
      settleLoanMatch(state);

      final cells = (state['grid'] as Map)['cells'] as List;
      expect((cells[0] as Map)['loanMatchesLeft'], 4);
      expect((cells[1] as Map)['loanMatchesLeft'], 2);
    });

    test('sends a player home when the spell ends', () {
      final state = _state(cards: [_card('a', loanMatchesLeft: 1)]);
      final report = settleLoanMatch(state);

      expect(report.departed.length, 1);
      expect(report.departed.first.reason, 'expired');
      expect(((state['grid'] as Map)['cells'] as List)[0], isNull);
    });

    test('clears the departed player from the XI', () {
      final lineup = <dynamic>[
        for (var i = 0; i < 11; i++)
          {'slotId': 's$i', 'slotPosition': 'MID', 'cardInstanceId': i == 0 ? 'a' : null},
      ];
      final state = _state(
        cards: [_card('a', loanMatchesLeft: 1)],
        lineup: lineup,
      );
      settleLoanMatch(state);
      expect((lineup.first as Map)['cardInstanceId'], isNull);
    });

    test('charges NO wage — that comes out of the income rate', () {
      // Taking it again at full time would bill the same player twice.
      final state = _state(cards: [_card('a', loanMatchesLeft: 5, loanWage: 500)]);
      final before = (state['resources'] as Map)['fanCoins'] as num;
      settleLoanMatch(state);
      expect((state['resources'] as Map)['fanCoins'], before);
    });

    test('leaves a tutorial borrowed card alone', () {
      final state = _state(cards: [_card('tut', borrowed: true)]);
      settleLoanMatch(state);
      expect(((state['grid'] as Map)['cells'] as List)[0], isNotNull);
    });

    test('a squad with no loans settles to nothing', () {
      final report = settleLoanMatch(_state(cards: [_card('a')]));
      expect(report.departed, isEmpty);
      expect(report.returned, isEmpty);
    });
  });

  group('enforceLoanWages', () {
    test('does nothing while the squad can pay', () {
      final state = _state(
        cards: [
          _card('earner', definitionId: 'player_t8_fwd'),
          _card('loanee', definitionId: 'player_t1_mid', loanMatchesLeft: 5),
        ],
      );
      expect(enforceLoanWages(state), isEmpty);
    });

    test('sends a loanee home when wages outrun income', () {
      // Cannot pay is not an empty wallet — it is wages outrunning earnings.
      final state = _state(
        // grantLoan marks a loanee `borrowed`, so it earns nothing — a loanee
        // costs twice: the wage, and the slot it fills without earning.
        cards: [
          _card('loanee', definitionId: 'player_t8_fwd', loanMatchesLeft: 5, borrowed: true),
        ],
      );
      final departed = enforceLoanWages(state);
      expect(departed.length, 1);
      expect(((state['grid'] as Map)['cells'] as List)[0], isNull);
    });

    test('gives up the DEAREST loan first, then re-checks', () {
      // A squad holding two gives up the one that fixes the problem, not both.
      final state = _state(
        cards: [
          _card('cheap', definitionId: 'player_t1_mid', loanMatchesLeft: 5, borrowed: true),
          _card('dear', definitionId: 'player_t8_fwd', loanMatchesLeft: 5, borrowed: true),
          _card('earner', definitionId: 'player_t7_fwd'),
        ],
      );
      final departed = enforceLoanWages(state);
      expect(departed.first.name, isNotEmpty);
      expect(departed.map((d) => d.card.definitionId), contains('player_t8_fwd'));
    });

    test('a forced departure earns the lender a grudge', () {
      // From their side it is the same insult as an early recall.
      final state = _state(
        cards: [
          _card(
            'loanee',
            definitionId: 'player_t8_fwd',
            loanMatchesLeft: 5,
            borrowed: true,
            loanFrom: 'Lender FC',
          ),
        ],
      );
      enforceLoanWages(state);
      final grudges = ((state['transferMarket'] as Map)['grudges'] as Map);
      expect(grudges['Lender FC'], isNotNull);
    });

    test('is bounded even against a pathological squad', () {
      final state = _state(
        cards: [
          for (var i = 0; i < 6; i++)
            _card('l$i', definitionId: 'player_t8_fwd', loanMatchesLeft: 5, borrowed: true),
        ],
      );
      expect(() => enforceLoanWages(state), returnsNormally);
    });
  });

  group('loaning out', () {
    test('pays the whole spell up front', () {
      // A lump is a decision you feel; a trickle was money with no connection
      // to anything.
      final state = _state(cards: [_card('a'), _card('b')]);
      final before = (state['resources'] as Map)['fanCoins'] as num;

      final r = loanOutPlayer(state, 'a', toTeam: 'Borrower FC');
      expect(r.ok, isTrue);
      expect(r.upFront, greaterThan(0));
      expect((state['resources'] as Map)['fanCoins'], before + r.upFront!);
      expect(r.upFront, math.max(1, (r.feePerMatch! * r.matches!).round()));
    });

    test('the player leaves the XI immediately', () {
      final lineup = <dynamic>[
        for (var i = 0; i < 11; i++)
          {'slotId': 's$i', 'slotPosition': 'MID', 'cardInstanceId': i == 0 ? 'a' : null},
      ];
      final state = _state(cards: [_card('a'), _card('b')], lineup: lineup);
      loanOutPlayer(state, 'a');
      expect((lineup.first as Map)['cardInstanceId'], isNull);
    });

    test('a star earns more than filler', () {
      final state = _state(cards: [_card('a'), _card('b')]);
      final star = loanOutFee(state, CardInstance(_card('s', definitionId: 'player_t8_fwd')));
      final filler = loanOutFee(state, CardInstance(_card('f', definitionId: 'player_t1_mid')));
      expect(star, greaterThan(filler));
    });

    test('a veteran is worth less to borrow', () {
      final state = _state();
      final young = loanOutFee(
        state,
        CardInstance(_card('y', definitionId: 'player_t8_fwd')),
      );
      final old = loanOutFee(
        state,
        CardInstance(_card('o', definitionId: 'player_t8_fwd', seasonsPlayed: 14)),
      );
      expect(old, lessThan(young));
    });

    test('renting out pays less than renting in costs', () {
      // Otherwise swapping squads back and forth would be a money printer.
      expect(loanOutFeeRate, lessThan(loanWageRate));
    });

    test('refuses to lend a loanee on', () {
      final state = _state(cards: [_card('borrowed', loanMatchesLeft: 5), _card('b')]);
      expect(loanOutPlayer(state, 'borrowed').reason, 'loan_card');
    });

    test('refuses an injured player', () {
      final state = _state(cards: [_card('hurt', injured: true), _card('b')]);
      expect(loanOutPlayer(state, 'hurt').reason, 'injured');
    });

    test('refuses to lend the last available player', () {
      final state = _state(cards: [_card('only')]);
      expect(loanOutPlayer(state, 'only').reason, 'last_player');
    });

    test('refuses past the cap', () {
      final state = _state(
        cards: [
          for (var i = 0; i < maxLoansOut; i++)
            _card('out$i', loanedOut: {'toTeam': 'X', 'matchesLeft': 5}),
          _card('a'),
          _card('b'),
        ],
      );
      expect(loanOutPlayer(state, 'a').reason, 'max_loans_out');
    });

    test('refuses one already away', () {
      final state = _state(
        cards: [
          _card('away', loanedOut: {'toTeam': 'X', 'matchesLeft': 5}),
          _card('b'),
          _card('c'),
        ],
      );
      expect(loanOutPlayer(state, 'away').reason, 'already_out');
    });
  });

  group('settleLoanOutMatch', () {
    test('burns a game and brings them home at the end', () {
      final state = _state(
        cards: [
          _card('a', loanedOut: {'toTeam': 'Borrower FC', 'matchesLeft': 1}),
          _card('b', loanedOut: {'toTeam': 'Other FC', 'matchesLeft': 5}),
        ],
      );
      final report = settleLoanOutMatch(state);

      expect(report.returned.length, 1);
      expect(report.returned.first.toTeam, 'Borrower FC');

      final cells = (state['grid'] as Map)['cells'] as List;
      expect((cells[0] as Map)['loanedOut'], isNull);
      expect(((cells[1] as Map)['loanedOut'] as Map)['matchesLeft'], 4);
    });

    test('banks NO fee — the spell was paid up front', () {
      final state = _state(
        cards: [
          _card('a', loanedOut: {
            'toTeam': 'X',
            'matchesLeft': 5,
            'feePerMatch': 500,
          }),
        ],
      );
      final before = (state['resources'] as Map)['fanCoins'] as num;
      final report = settleLoanOutMatch(state);
      expect(report.feesEarned, 0);
      expect((state['resources'] as Map)['fanCoins'], before);
    });

    test('settles at the same instant as loans in', () {
      final state = _state(
        cards: [
          _card('in', loanMatchesLeft: 3),
          _card('out', loanedOut: {'toTeam': 'X', 'matchesLeft': 3}),
        ],
      );
      settleLoanMatch(state);

      final cells = (state['grid'] as Map)['cells'] as List;
      expect((cells[0] as Map)['loanMatchesLeft'], 2);
      expect(((cells[1] as Map)['loanedOut'] as Map)['matchesLeft'], 2);
    });
  });

  group('recallLoan', () {
    test('a completed spell comes home cleanly', () {
      final state = _state(
        cards: [_card('a', loanedOut: {'toTeam': 'X', 'matchesLeft': 0})],
      );
      final r = recallLoan(state, 'a');
      expect(r.ok, isTrue);
      expect(r.early, isFalse);
      expect((state['transferMarket'] as Map?)?['grudges'], anyOf(isNull, isEmpty));
    });

    test('an early recall costs a grudge', () {
      // The borrowing club planned around that player — it costs what breaking
      // any other promise costs.
      final state = _state(
        cards: [_card('a', loanedOut: {'toTeam': 'Borrower FC', 'matchesLeft': 4})],
      );
      final r = recallLoan(state, 'a');
      expect(r.early, isTrue);

      final grudges = (state['transferMarket'] as Map)['grudges'] as Map;
      expect(grudges['Borrower FC'], isNotNull);
    });

    test('the player is available again afterwards', () {
      final state = _state(
        cards: [_card('a', loanedOut: {'toTeam': 'X', 'matchesLeft': 4})],
      );
      recallLoan(state, 'a');
      final card = CardInstance(((state['grid'] as Map)['cells'] as List)[0] as Map<String, dynamic>);
      expect(isLoanedOut(card), isFalse);
      expect(card.isUnavailable, isFalse);
    });

    test('refuses a player who is not away', () {
      final state = _state(cards: [_card('a')]);
      expect(recallLoan(state, 'a').reason, 'not_loaned_out');
      expect(recallLoan(state, 'nobody').reason, 'not_loaned_out');
    });
  });
}
