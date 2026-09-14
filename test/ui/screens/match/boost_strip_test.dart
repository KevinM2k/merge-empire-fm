/// The two proactive boosts on the match screen, and everything that says one
/// is live: the strip, the burning bar, the glow, the one-at-a-time pill, and
/// the "Active" list in the statboard.
///
/// Harness borrowed from `match_screen_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/boost_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show strategies;
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart'
    show CutawayOutcome;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';

import 'match_screen_test.dart';

Map<String, dynamic> _playable({bool isHome = true}) => {
  ...matchResult(isHome: isHome, addedTime: 0),
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

Map<String, dynamic> _save({
  Map<String, int> boosts = const {'crowd_roar': 2, 'park_the_bus': 1},
  String? trait,
}) {
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
  s['matchBoosts'] = Map<String, dynamic>.from(boosts);
  return s;
}

/// Wind the clock to [minute], finishing any chance the pitch is retelling —
/// a cutaway stops the clock, and a re-simulation writes fresh chances into
/// the minutes ahead, so a single long pump after a tap stalls on the first.
Future<void> _runTo(WidgetTester tester, MatchScreenState state, int minute) async {
  for (var i = 0; i < 400 && state.frame.minute < minute && !state.frame.finished; i++) {
    if (state.clipPlaying) {
      tester.widget<CutawayStage>(find.byType(CutawayStage)).onDone!(
        CutawayOutcome.goal,
      );
      await tester.pump();
      continue;
    }
    await tester.pump(minuteDurationFor(1));
  }
}

Future<void> _finish(WidgetTester tester, MatchScreenState state) async {
  state.skipToEnd();
  await tester.pumpAndSettle();
  await settleSave(tester);
}

void main() {
  group('THE BOOST STRIP', () {
    testWidgets('shows the two proactive boosts with what you own', (
      tester,
    ) async {
      await pumpMatch(tester, _playable(), save: _save(), instance: 'strip');
      expect(find.byKey(const ValueKey('match-boosts')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-boost-crowd_roar')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-boost-park_the_bus')), findsOneWidget);
      // Only the proactive pair: the bench boosts are not here.
      expect(find.byKey(const ValueKey('match-boost-var_review')), findsNothing);
      expect(find.byKey(const ValueKey('match-boost-physio_sponge')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('match-boost-count-crowd_roar'))).data,
        'x2',
      );
      await _finish(tester, stateOf(tester));
    });

    testWidgets('AN UNOWNED BOOST SHOWS ITS PRICE AND GOES TO THE SHOP', (
      tester,
    ) async {
      final c = await pumpMatch(
        tester,
        _playable(),
        save: _save(boosts: const {}),
        instance: 'unowned',
      );
      expect(find.byKey(const ValueKey('match-boost-price-crowd_roar')), findsOneWidget);
      final before = stateOf(tester).resimCount;
      await tester.tap(find.byKey(const ValueKey('match-boost-crowd_roar')));
      await tester.pump();
      // Nothing was spent and nothing re-decided; the shop was asked for.
      expect(stateOf(tester).resimCount, before);
      expect(c.read(shellControllerProvider).pendingShopSection, ShopSection.boosts);
      await _finish(tester, stateOf(tester));
    });

    testWidgets('CROWD ROAR: debits, opens a window, lifts the side, and says so', (
      tester,
    ) async {
      final c = await pumpMatch(tester, _playable(), save: _save(), instance: 'roar');
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      expect(find.byKey(const ValueKey('match-live-source-pill')), findsNothing);
      expect(find.byKey(const ValueKey('match-live-glow')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('match-boost-crowd_roar')));
      await tester.pump();

      expect(boostCount(c.read(gameProvider).state, 'crowd_roar'), 1);
      expect(state.boostWindows.single.id, 'crowd_roar');
      expect(state.boostWindows.single.toMinute, state.frame.minute + 25);
      expect(state.resimCount, 1);
      expect(find.byKey(const ValueKey('match-boost-band-crowd_roar')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-live-glow')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-live-source-pill')), findsOneWidget);
      expect(state.notes.any((n) => n.key == 'boost.roar.live'), isTrue);
      final lifted = state.liveRatings['liveSquadRating'] as num;

      // The pill is a caption for the MOMENT: gone in a few seconds, the glow
      // still there.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('match-live-source-pill')), findsNothing);
      expect(find.byKey(const ValueKey('match-live-glow')), findsOneWidget);

      // Run past the window: the remainder is re-decided once more, without
      // the lift, and the feed says the noise settled.
      await _runTo(tester, state, state.boostWindows.single.toMinute + 1);
      expect(
        state.boostWindows,
        isEmpty,
        reason: 'minute ${state.frame.minute}, paused ${state.paused}, '
            'resims ${state.resimCount}, pending ${state.pendingResims}',
      );
      expect(state.resimCount, 2);
      expect(find.byKey(const ValueKey('match-boost-band-crowd_roar')), findsNothing);
      expect(state.notes.any((n) => n.key == 'boost.roar.over'), isTrue);
      final after = state.liveRatings['liveSquadRating'] as num;
      expect(lifted, greaterThan(after));
      await _finish(tester, state);
    });

    testWidgets('PARK THE BUS damps the goal rate rather than the rating', (
      tester,
    ) async {
      await pumpMatch(tester, _playable(), save: _save(), instance: 'bus');
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      await tester.tap(find.byKey(const ValueKey('match-boost-park_the_bus')));
      await tester.pump();
      expect(state.boostWindows.single.id, 'park_the_bus');
      expect(find.byKey(const ValueKey('match-boost-band-park_the_bus')), findsOneWidget);
      expect(state.notes.any((n) => n.key == 'boost.bus.live'), isTrue);
      // A Bus is not a rating change: the live figure is the plain one.
      final bussed = state.liveRatings['liveSquadRating'] as num;
      await _finish(tester, state);

      await pumpMatch(tester, _playable(), save: _save(), instance: 'plain');
      final plain = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      plain.applyStrategy(strategies.keys.firstWhere((id) => id != plain.strategy));
      await tester.pump();
      expect(bussed, plain.liveRatings['liveSquadRating']);
      await _finish(tester, plain);
    });

    testWidgets('TWO ROARS STACK, and the window runs to the later end', (
      tester,
    ) async {
      await pumpMatch(tester, _playable(), save: _save(), instance: 'stack');
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(30));
      await tester.tap(find.byKey(const ValueKey('match-boost-crowd_roar')));
      await tester.pump();
      await _runTo(tester, state, state.frame.minute + 5);
      await tester.tap(find.byKey(const ValueKey('match-boost-crowd_roar')));
      await tester.pump();
      expect(state.boostWindows.length, 2);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('match-boost-until-crowd_roar'))).data,
        contains("${state.boostWindows.last.toMinute}'"),
      );
      await _finish(tester, state);
    });
  });

  group('WHAT IS LIFTING THE SIDE', () {
    // The board already moves — `ourRating` reads the live figure — and a
    // kickoff-condition trait has nothing to EXPLAIN: the board opens at that
    // value. So the glow is on and the pill is not.
    testWidgets('A KICKOFF TRAIT GLOWS BUT POSTS NO PILL', (tester) async {
      await pumpMatch(
        tester,
        _playable(isHome: true),
        save: _save(boosts: const {}, trait: 'fortress'),
        instance: 'kickoff-trait',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('match-live-glow')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-live-source-pill')), findsNothing);
      await _finish(tester, stateOf(tester));
    });

    testWidgets('and nothing glows with nothing lifting', (tester) async {
      await pumpMatch(
        tester,
        _playable(isHome: false),
        save: _save(boosts: const {}, trait: 'fortress'),
        instance: 'dark-trait',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('match-live-glow')), findsNothing);
      await _finish(tester, stateOf(tester));
    });

    testWidgets('LAST GASP POSTS ITS PILL WHEN IT SWITCHES ON', (tester) async {
      await pumpMatch(
        tester,
        _playable(),
        save: _save(boosts: const {}, trait: 'last_gasp'),
        instance: 'gasp-pill',
      );
      final state = stateOf(tester);
      for (var i = 0; i < 76; i++) {
        await tester.pump(minuteDurationFor(1));
      }
      expect(state.frame.minute, 76);
      expect(find.byKey(const ValueKey('match-live-source-pill')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('match-live-source-pill-text'))).data,
        contains('Last Gasp'),
      );
      await _finish(tester, state);
    });

    testWidgets('THE STATBOARD LISTS EVERYTHING RUNNING', (tester) async {
      await pumpMatch(
        tester,
        _playable(),
        save: _save(trait: 'fortress'),
        instance: 'active-list',
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      await tester.tap(find.byKey(const ValueKey('match-boost-crowd_roar')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('match-stats-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-active')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-active-crowd_roar')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-active-fortress')), findsOneWidget);
      expect(find.textContaining("${state.boostWindows.single.toMinute}'"), findsWidgets);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _finish(tester, state);
    });
  });
}
