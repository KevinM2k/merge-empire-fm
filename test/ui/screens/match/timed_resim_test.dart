/// The remainder re-decided at a minute nobody taps.
///
/// Fast Starter stops paying at 21 and Last Gasp starts at 76, and a boost's
/// window has to end somewhere — none of them has a manager input to ride on,
/// so the screen queues a re-simulation for the minute itself. This proves the
/// queue fires, fires ONCE, and fires with the trait in the state it should be
/// in on that side of the boundary.
///
/// Harness borrowed from `match_screen_test.dart`, as `match_trait_wiring_test`
/// does.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show strategies;
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';

import 'match_screen_test.dart';

Map<String, dynamic> _playable() => {
  ...matchResult(isHome: true, addedTime: 0),
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

Future<MatchScreenState> _pumpTo(
  WidgetTester tester,
  int minute, {
  String? trait,
  required String instance,
}) async {
  await pumpMatch(
    tester,
    _playable(),
    save: _save(trait: trait),
    instance: instance,
  );
  for (var i = 0; i < minute; i++) {
    await tester.pump(minuteDurationFor(1));
  }
  return stateOf(tester);
}

Future<void> _finish(WidgetTester tester, MatchScreenState state) async {
  state.skipToEnd();
  await settleSave(tester);
}

void main() {
  group('A SCHEDULED RE-SIMULATION', () {
    testWidgets('NOBODY IN THE ELEVEN CARRIES A MINUTE TRAIT: none is queued', (
      tester,
    ) async {
      final state = await _pumpTo(tester, 30, instance: 'none');
      expect(state.resimCount, 0);
      await _finish(tester, state);
    });

    testWidgets('Fast Starter re-decides the rest at 21, once', (
      tester,
    ) async {
      final state = await _pumpTo(
        tester,
        20,
        trait: 'fast_starter',
        instance: 'fast-20',
      );
      expect(state.resimCount, 0, reason: 'fired before the window closed');
      await tester.pump(minuteDurationFor(1));
      expect(state.frame.minute, 21);
      expect(state.resimCount, 1);
      await tester.pump(minuteDurationFor(10));
      expect(state.resimCount, 1, reason: 'a boundary fires once');
      await _finish(tester, state);
    });

    testWidgets('and on that side of the boundary the trait is DARK', (
      tester,
    ) async {
      // The re-sim at 21 must roll with Fast Starter switched off — that is
      // the whole point of scheduling it — so the live figure it writes is the
      // plain one, not the lit one.
      final lit = await _pumpTo(
        tester,
        25,
        trait: 'fast_starter',
        instance: 'fast-dark',
      );
      final auto = lit.liveRatings['liveSquadRating'] as num;
      await _finish(tester, lit);

      final plain = await _pumpTo(tester, 25, instance: 'plain-25');
      plain.applyStrategy(
        strategies.keys.firstWhere((id) => id != plain.strategy),
      );
      await tester.pump();
      final manual = plain.liveRatings['liveSquadRating'] as num;
      await _finish(tester, plain);

      expect(auto, manual);
    });

    testWidgets('Last Gasp re-decides the rest at 76, and is LIT there', (
      tester,
    ) async {
      final state = await _pumpTo(
        tester,
        75,
        trait: 'last_gasp',
        instance: 'gasp-75',
      );
      expect(state.resimCount, 0);
      await tester.pump(minuteDurationFor(1));
      expect(state.resimCount, 1);
      final lit = state.liveRatings['liveSquadRating'] as num;
      await _finish(tester, state);

      final control = await _pumpTo(tester, 76, instance: 'plain-76');
      control.applyStrategy(
        strategies.keys.firstWhere((id) => id != control.strategy),
      );
      await tester.pump();
      final plain = control.liveRatings['liveSquadRating'] as num;
      await _finish(tester, control);

      expect(lit, greaterThan(plain));
    });

    testWidgets('a boundary already behind the clock is not queued', (
      tester,
    ) async {
      final state = await _pumpTo(tester, 5, instance: 'behind');
      state.scheduleResimAt(3, 'test');
      await tester.pump(minuteDurationFor(5));
      expect(state.resimCount, 0);
      await _finish(tester, state);
    });
  });
}
