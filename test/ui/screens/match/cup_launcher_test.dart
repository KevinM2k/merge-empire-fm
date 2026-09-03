/// Playing a cup tie.
///
/// The engine was ported, tested, and reachable by nothing: `prepareCupRound`
/// and `commitCupRound` had no caller, so a club could be entered into a cup and
/// never play a round of it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// A save in a division with a cup, with a squad and a bracket already drawn.
Map<String, dynamic> cupState({
  int energy = 10,
  int matchesPlayed = 4,
  int round = 0,
  bool pro = false,
}) {
  final s = createDefaultState();
  (s['energy'] as Map<String, dynamic>)['current'] = energy;
  (s['settings'] as Map<String, dynamic>)['hardMode'] = pro;
  s['clubName'] = 'Testville';

  final prog = s['progression'] as Map<String, dynamic>;
  // The first division that has a cup at all — the Regional League, which is
  // where `regional_cup` unlocks. Below it there is no cup to be entered into.
  prog['currentDivision'] = divisions[cups.first.unlocksAtDivisionIdx].id;
  prog['seasonMatchesPlayed'] = matchesPlayed;
  prog['seasonOpponents'] = ['Ayton', 'Beeches', 'Cadley', 'Deeping'];

  final def = players.firstWhere((p) => p.tier == 1);
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < 11; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': def.id,
      'instanceId': 'c$i',
      'variant': 0,
    };
  }
  (s['squad'] as Map<String, dynamic>)['lineup'] = [
    for (var i = 0; i < 11; i++)
      <String, dynamic>{
        'slotId': 's$i',
        'slotPosition': 'MID',
        'cardInstanceId': 'c$i',
      },
  ];

  final cup = cupForDivision(s);
  prog['cups'] = <String, dynamic>{
    'availableThisSeason': false,
    'active': cup == null
        ? null
        : <String, dynamic>{
            'cupId': cup.id,
            'round': round,
            'opponents': [for (final name in cup.rounds) 'Rival $name'],
            'opponentMeta': [
              for (final _ in cup.rounds)
                <String, dynamic>{
                  'divId': prog['currentDivision'],
                  'rating': 50,
                  'attackRatio': 0.5,
                },
            ],
            'contexts': <dynamic>[],
            'results': <dynamic>[],
            'startedAt': 0,
            'startedSeason': 1,
          },
    'history': <dynamic>[],
  };
  return s;
}

int _coins(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

int _energy(Map<String, dynamic> s) =>
    ((s['energy'] as Map<String, dynamic>)['current'] as num).toInt();

/// The rounds played, wherever they ended up.
///
/// A win leaves them on the live run; a defeat ends the run and the whole thing
/// moves into the history, so a test that only reads `active` sees an empty list
/// exactly half the time.
List<dynamic> _cupResults(Map<String, dynamic> s) {
  final cups = _map(_map(s['progression'])?['cups']);
  final active = _map(cups?['active']);
  final live = active?['results'];
  if (live is List && live.isNotEmpty) return live;
  final history = cups?['history'];
  if (history is List && history.isNotEmpty) {
    final last = _map(history.last)?['results'];
    if (last is List) return last;
  }
  return const [];
}

void main() {
  tearDown(clearBus);

  group('when a tie is due', () {
    test('not until the league matches before it have been played', () {
      // The thresholds are the fixture list's own: a tie is due AFTER the league
      // match it sits behind.
      expect(cupDue(cupState(matchesPlayed: 0)), isFalse);
      expect(cupDue(cupState(matchesPlayed: 3)), isFalse);
      expect(cupDue(cupState(matchesPlayed: 4)), isTrue);
    });

    test('the second round waits for its own threshold', () {
      expect(cupDue(cupState(round: 1, matchesPlayed: 4)), isFalse);
      expect(cupDue(cupState(round: 1, matchesPlayed: 9)), isTrue);
    });

    test('a save with no cup run has none due', () {
      final s = cupState();
      (_map(s['progression'])!['cups'] as Map<String, dynamic>)['active'] =
          null;
      expect(cupDue(s), isFalse);
      expect(nextCupRound(s), isNull);
    });

    test('a round past the last threshold is not due', () {
      // Three thresholds, so a fourth round has nowhere to sit.
      expect(cupDue(cupState(round: 3, matchesPlayed: 14)), isFalse);
    });

    test('the round names itself, for the button', () {
      final s = cupState();
      final next = nextCupRound(s)!;
      expect(next.round, 0);
      expect(next.roundName, next.cup.rounds.first);
    });
  });

  group('starting one', () {
    test('spends a pip and hands back something playable', () {
      final s = cupState();
      final before = _energy(s);
      final tie = beginCupRound(s)!;

      expect(_energy(s), lessThan(before));
      expect(tie.result['isCup'], isTrue);
      expect(tie.result['clubName'], 'Testville');
      expect(tie.result['opponentName'], isNotEmpty);
      expect(tie.result['events'], isA<List<dynamic>>());
    });

    test('Pro mode spends no pip', () {
      // Fatigue is per player there, and a cup tie is not an exception to it.
      final s = cupState(pro: true);
      final before = _energy(s);
      expect(beginCupRound(s), isNotNull);
      expect(_energy(s), before);
    });

    test('and nothing at all happens when no tie is due', () {
      final s = cupState(matchesPlayed: 0);
      final before = _energy(s);
      expect(beginCupRound(s), isNull);
      expect(_energy(s), before);
    });

    test('an empty pip refuses, and keeps the round unplayed', () {
      final s = cupState(energy: 0);
      expect(beginCupRound(s), isNull);
      expect(_cupResults(s), isEmpty);
    });

    test('the feed plays the ninety minutes, not the shootout', () {
      // The engine folds the shootout winner's goal into the scoreline so `won`
      // and the score agree. A feed that played it would have a goal in the
      // ninetieth minute that never happened.
      final s = cupState();
      final tie = beginCupRound(s)!;
      final events = (tie.result['events'] as List)
          .cast<Map<String, dynamic>>();
      final goals = events.where((e) => e['type'] == 'goal').length;
      final shootout = _map(tie.result['penaltyShootout']);
      final scored =
          (tie.result['homeGoals'] as num) + (tie.result['awayGoals'] as num);
      expect(goals, shootout == null ? scored : scored - 1);
    });

    test('THE BOARD GETS A RATING FOR BOTH SIDES, which it did not', () {
      // Reported from the couch: a sending-off in a cup tie left the
      // opposition's figure at the top of the match popup reading 0. It read 0
      // from kick-off — the tie carried `squadRating`/`opponentRating` and the
      // board reads the `effective*` pair — and the red card is what made it
      // visible, because the re-simulation fills OUR half in from the live
      // squad and nothing ever filled theirs.
      final s = cupState();
      final tie = beginCupRound(s)!;
      expect(tie.result['effectiveSquadRating'], tie.prepared.squadRating);
      expect(tie.result['effectiveOppRating'], tie.prepared.opponentRating);
      expect(tie.result['effectiveOppRating'], greaterThan(0));
    });

    test('and it carries a match quest track like any other match', () {
      final s = cupState();
      beginCupRound(s);
      final active =
          ((s['quests'] as Map<String, dynamic>)['match']
                  as Map<String, dynamic>)['active']
              as List;
      expect(active, hasLength(matchQuestCount));
    });
  });

  group('settling one', () {
    test('records the round and pays the prize', () {
      final s = cupState();
      final coinsBefore = _coins(s);
      final tie = beginCupRound(s)!;
      settleCupRound(s, tie);

      expect(_cupResults(s), hasLength(1));
      expect(_coins(s), greaterThan(coinsBefore));
    });

    test('and judges the match quests, as a league game does', () {
      // A cup tie was the one match where the quests on the Play screen counted
      // for nothing.
      final s = cupState();
      final tie = beginCupRound(s)!;
      settleCupRound(s, tie);
      expect((tie.result['questResults'] as List), hasLength(matchQuestCount));
    });

    test('a win moves the bracket on, a defeat ends the run', () {
      final s = cupState();
      final tie = beginCupRound(s)!;
      final won = tie.prepared.won;
      settleCupRound(s, tie);

      final active = _map(_map(_map(s['progression'])?['cups'])?['active']);
      if (won) {
        expect(active, isNotNull);
        expect((active!['round'] as num).toInt(), 1);
      } else {
        expect(active, isNull, reason: 'knocked out');
      }
    });
  });

  group('the sponsor a win can drop', () {
    CupSponsorDrop drop(Map<String, dynamic> s, {int cellIdx = 0}) => (
      kind: 'player_sponsor',
      cellIdx: cellIdx,
      sponsorData: cupPlayerSponsors.first,
      playerName: 'Somebody',
    );

    test('lands on the card it was offered for, once accepted', () {
      final s = cupState();
      expect(acceptCupSponsorDrop(s, drop(s)), isTrue);
      final card = _map(
        ((s['grid'] as Map<String, dynamic>)['cells'] as List).first,
      )!;
      expect(_map(card['sponsor'])?['name'], cupPlayerSponsors.first.name);
      expect(
        _map(card['sponsor'])?['multiplier'],
        cupPlayerSponsors.first.multiplier,
      );
    });

    test('a card that already has one is left alone', () {
      // A second cup win must not overwrite a deal the player is living with.
      final s = cupState();
      expect(acceptCupSponsorDrop(s, drop(s)), isTrue);
      final other = cupPlayerSponsors.last;
      final second = (
        kind: 'player_sponsor',
        cellIdx: 0,
        sponsorData: other,
        playerName: 'Somebody',
      );
      expect(acceptCupSponsorDrop(s, second), isFalse);
      final card = _map(
        ((s['grid'] as Map<String, dynamic>)['cells'] as List).first,
      )!;
      expect(_map(card['sponsor'])?['name'], cupPlayerSponsors.first.name);
    });

    test('a card that has gone since the tie is refused, not crashed on', () {
      final s = cupState();
      ((s['grid'] as Map<String, dynamic>)['cells'] as List)[0] = null;
      expect(acceptCupSponsorDrop(s, drop(s)), isFalse);
      expect(acceptCupSponsorDrop(s, drop(s, cellIdx: 999)), isFalse);
    });

    test('and it says so, so the card can be seen to be signed', () {
      final s = cupState();
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('cup:sponsor-signed', listener);
      addTearDown(() => off('cup:sponsor-signed', listener));

      acceptCupSponsorDrop(s, drop(s));
      expect(heard, hasLength(1));
    });
  });

  group('a tactic change mid-tie', () {
    // `reSimulateRemainder` rewrites the result's scoreline IN PLACE — its own
    // first line says so — and `PreparedCupRound` is a record, so the figure
    // the commit was given at kickoff cannot be updated. Without the override
    // the bracket recorded the pre-match simulation while the player watched a
    // different score.
    test('THE BRACKET RECORDS WHAT THE SCREEN ENDED ON', () {
      final s = cupState();
      final tie = beginCupRound(s)!;
      // What the screen would have done: a re-sim, in place.
      tie.result['homeGoals'] = 4;
      tie.result['awayGoals'] = 1;
      tie.result['won'] = true;
      settleCupRound(s, tie);

      final stored = _map(_cupResults(s).single)!;
      expect(stored['homeGoals'], 4);
      expect(stored['awayGoals'], 1);
      expect(stored['won'], isTrue);
    });

    test('and a re-simulated defeat ends the run, whatever was prepared', () {
      final s = cupState();
      final tie = beginCupRound(s)!;
      tie.result['homeGoals'] = 0;
      tie.result['awayGoals'] = 2;
      tie.result['won'] = false;
      settleCupRound(s, tie);

      expect(
        _map(_map(_map(s['progression'])?['cups'])?['active']),
        isNull,
        reason: 'a defeat should have ended it',
      );
    });

    test('A CUP TIE CANNOT END LEVEL, and a re-sim is free to make it one', () {
      // The ninety-minute engine has no opinion about that — in the league a
      // draw is a result — so the shootout rolled for exactly this case
      // decides it rather than a fresh draw from the same hat.
      final s = cupState();
      final tie = beginCupRound(s)!;
      tie.result['homeGoals'] = 2;
      tie.result['awayGoals'] = 2;
      tie.result['won'] = false;
      tie.result['penaltyShootout'] = <String, dynamic>{
        'playerWins': true,
        'homeScore': 5,
        'awayScore': 4,
        'kicks': <dynamic>[],
      };
      settleCupRound(s, tie);

      expect(_map(_cupResults(s).single)!['won'], isTrue);
      expect(
        _map(_map(_map(s['progression'])?['cups'])?['active']),
        isNotNull,
        reason: 'winning on penalties should carry the run on',
      );
    });

    test('and with no shootout to fall back on it keeps what was prepared', () {
      final s = cupState();
      final tie = beginCupRound(s)!;
      final prepared = tie.prepared.won;
      tie.result['homeGoals'] = 1;
      tie.result['awayGoals'] = 1;
      tie.result['won'] = false;
      tie.result['penaltyShootout'] = null;
      settleCupRound(s, tie);
      expect(_map(_cupResults(s).single)!['won'], prepared);
    });

    test('AND THE CARD AFTERWARDS READS THE SAME ANSWER', () {
      // **Reported from the couch: a cup tie that finished level and produced
      // the victory screen anyway.** `_sayHowItWent` in `play_button.dart`
      // asked `tie.prepared.won` — the simulation from BEFORE the tie was
      // played — while the bracket was written from the settled result. A
      // substitution, a booking or a tactic change re-simulates the remainder,
      // and a remainder that ends level re-rolls the shootout with it, so the
      // two disagree exactly when it matters: the run was over and the card
      // said "through to the next round".
      //
      // So the settled answer goes back onto the result, which is what every
      // screen after this one reads.
      final s = cupState();
      final tie = beginCupRound(s)!;
      tie.result['homeGoals'] = 1;
      tie.result['awayGoals'] = 1;
      // Whatever the screen last thought, before the level check runs.
      tie.result['won'] = true;
      tie.result['drawn'] = true;
      tie.result['penaltyShootout'] = <String, dynamic>{
        'playerWins': false,
        'homeScore': 3,
        'awayScore': 4,
        'kicks': <dynamic>[],
      };
      settleCupRound(s, tie);

      expect(
        tie.result['won'],
        isFalse,
        reason: 'the card would have celebrated an elimination',
      );
      expect(tie.result['drawn'], isFalse, reason: 'a cup tie cannot end level');
      expect(_map(_cupResults(s).single)!['won'], tie.result['won']);
      expect(
        _map(_map(_map(s['progression'])?['cups'])?['active']),
        isNull,
        reason: 'losing on penalties should have ended the run',
      );
    });

    test('and it agrees with the bracket on a win, too', () {
      final s = cupState();
      final tie = beginCupRound(s)!;
      tie.result['homeGoals'] = 2;
      tie.result['awayGoals'] = 2;
      tie.result['won'] = false;
      tie.result['penaltyShootout'] = <String, dynamic>{
        'playerWins': true,
        'homeScore': 5,
        'awayScore': 4,
        'kicks': <dynamic>[],
      };
      settleCupRound(s, tie);
      expect(tie.result['won'], isTrue);
      expect(_map(_cupResults(s).single)!['won'], isTrue);
    });

    test('an untouched result still commits the prepared score', () {
      // The overwhelming case: nobody changed anything.
      final s = cupState();
      final tie = beginCupRound(s)!;
      settleCupRound(s, tie);
      final stored = _map(_cupResults(s).single)!;
      expect(stored['homeGoals'], tie.prepared.homeGoals);
      expect(stored['awayGoals'], tie.prepared.awayGoals);
    });
  });
}
