/// **THIS IS THE REACHABILITY TEST, not a maths test.**
///
/// The arithmetic is pinned in `match_trait_engine_test`; what this proves is
/// that a trait on a card in the SAVE actually reaches the sim when the screen
/// re-simulates. A widget test that constructs the state it needs is exactly
/// the gap `tool/unreached.sh` exists to find, so this one plays a real
/// fixture through the screen and reads the live ratings back.
///
/// The harness is `match_screen_test.dart`'s own — `pumpMatch`, `squadSave`,
/// `stateOf` — imported rather than copied, so the two files cannot drift
/// apart on how a match is put on screen.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show strategies;
import 'package:merge_empire_fc/util/random.dart' show setSeed;

import 'match_screen_test.dart';

/// A result with enough on it for `reSimulateRemainder` to work with. It
/// rewrites the scoreline from the ratings, so a result with none of them
/// re-decides the match as 0-0 and proves nothing.
Map<String, dynamic> _playable({required bool isHome, num grudge = 0}) => {
  ...matchResult(isHome: isHome, addedTime: 0),
  // A grudge the sim stamped — Derby Devil's condition, and the one the port
  // reads off the result rather than the save.
  'grudgeBoost': grudge,
  'strategyId': 'balanced',
  'strategiesUsed': ['balanced'],
  'strategyChanged': false,
  'followedCoachSuggestion': false,
  'ourAttackRating': 60,
  'ourDefenceRating': 55,
  'effectiveSquadRating': 58,
  'squadRating': 58,
  'effOppAttackRating': 50,
  'effOppDefenceRating': 52,
  'effectiveOppRating': 51,
  'opponentRating': 51,
  'homeGoals': 0,
  'awayGoals': 0,
};

/// `squadSave`'s grid with the first eleven in the lineup, and optionally a
/// match trait in an OPEN slot on every one of them.
Map<String, dynamic> _save({String? trait}) {
  final s = squadSave();
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
  (s['squad'] as Map<String, dynamic>)['lineup'] = [
    for (var i = 0; i < 11; i++)
      <String, dynamic>{
        'slotId': 's$i',
        'slotPosition': 'MID',
        'cardInstanceId': 'c$i',
      },
  ];
  if (trait != null) {
    for (var i = 0; i < 11; i++) {
      (cells[i] as Map<String, dynamic>)
        ..['matchSlot'] = true
        ..['matchTrait'] = {'id': trait, 'level': 3};
    }
  }
  return s;
}

/// Play to minute 20, switch tactic — the re-simulation every trait needs to
/// take effect — and read the squad rating the remainder was rolled with.
Future<num> _liveSquadRating(
  WidgetTester tester, {
  required bool isHome,
  String? trait,
  num grudge = 0,
  required String instance,
}) async {
  // **THE SAME STREAM FOR BOTH PUMPS.** A tactic switch re-rolls the injuries
  // off the shared seeded stream, and a second pump continues that stream from
  // wherever the first left it — so without this, one of the two sides could
  // lose a man to a knock and the comparison was a coin toss.
  setSeed(7);
  await pumpMatch(
    tester,
    _playable(isHome: isHome, grudge: grudge),
    save: _save(trait: trait),
    instance: instance,
  );
  await tester.pump(minuteDurationFor(20));
  final state = stateOf(tester);
  state.applyStrategy(
    strategies.keys.firstWhere((id) => id != state.strategy),
  );
  await tester.pump();
  final live = state.liveRatings['liveSquadRating'] as num;
  state.skipToEnd();
  // A tactic change re-decides the rest and the fixture row goes with it, so
  // this arms the debounced save like a substitution does.
  await settleSave(tester);
  return live;
}

void main() {
  group('A MATCH TRAIT IN THE SAVE REACHES THE SIM', () {
    // Derby Devil rather than Fortress for the RATING check: a squad of
    // tier-one cards rates about fourteen, and +11% rounds away on the board
    // where +28% does not. The map tests below pin Fortress at its own number.
    testWidgets('A LIT TRAIT LIFTS THE RATING THE REMAINDER IS ROLLED WITH', (
      tester,
    ) async {
      final plain = await _liveSquadRating(
        tester,
        isHome: true,
        grudge: 5,
        instance: 'plain-derby',
      );
      final lit = await _liveSquadRating(
        tester,
        isHome: true,
        grudge: 5,
        trait: 'derby_devil',
        instance: 'devil-derby',
      );
      expect(lit, greaterThan(plain));
    });

    // The condition is read off the RESULT, not assumed: the same trait away
    // from home is dark, and a dark trait hands the sim NOTHING — asserted on
    // the map itself, which is what the re-simulation is given.
    testWidgets('and the same Fortress away from home does nothing', (
      tester,
    ) async {
      setSeed(7);
      await pumpMatch(
        tester,
        _playable(isHome: false),
        save: _save(trait: 'fortress'),
        instance: 'fortress-away',
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(20));
      expect(state.liveMultipliersAt(state.frame.minute), isEmpty);
      state.skipToEnd();
      await settleSave(tester);
    });

    testWidgets('and at home the map carries every man at his level', (
      tester,
    ) async {
      setSeed(7);
      await pumpMatch(
        tester,
        _playable(isHome: true),
        save: _save(trait: 'fortress'),
        instance: 'fortress-map',
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(20));
      final map = state.liveMultipliersAt(state.frame.minute);
      expect(map.length, 11);
      for (final v in map.values) {
        expect(v, closeTo(1.11, 1e-9));
      }
      state.skipToEnd();
      await settleSave(tester);
    });
  });
}
