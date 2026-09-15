/// The two proactive boosts on the match screen, and everything that says one
/// is live: the strip, the burning bar, the glow, the one-at-a-time pill, and
/// the "Active" list in the statboard.
///
/// Harness borrowed from `match_screen_test.dart`.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart' show getPlayerDef, ratioRange;
import 'package:merge_empire_fc/engine/boost_engine.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show strategies;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart'
    show CutawayOutcome;
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';
import 'package:merge_empire_fc/ui/screens/match/boost_bar_paint.dart' show AuraMemory;
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/util/random.dart' show setSeed;

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
  // `migrateRatios` back-fills each card's ATK/DEF split off an unseeded
  // generator at load, so without this every run rates the eleven a point apart.
  for (final c in cells.whereType<Map<String, dynamic>>()) {
    final (lo, hi) = ratioRange[getPlayerDef(c['definitionId'] as String?)?.position]!;
    c['attackRatio'] = (lo + hi) / 2;
  }
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

/// Call [id] off its chip on the pitch.
Future<void> _call(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('match-boost-$id')));
  await tester.pump();
}

void main() {
  // The shared stream is seeded off the wall clock, and injuries and cautions
  // come off it — either moves the star the ratings below compare. See
  // `match_trait_wiring_test` for the same trap.
  setUp(() => setSeed(7));

  group('THE BOOST STRIP', () {
    testWidgets('IS THREE CHIPS ON THE PITCH, one tap each', (tester) async {
      await pumpMatch(tester, _playable(), save: _save(), instance: 'strip');
      final state = stateOf(tester);
      final pitch = tester.getRect(find.byKey(const ValueKey('match-stage')));
      final chips = tester.getRect(find.byKey(const ValueKey('match-boosts')));
      expect(pitch.contains(chips.center), isTrue, reason: 'on the grass');
      expect(find.byKey(const ValueKey('match-boost-crowd_roar')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-boost-park_the_bus')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-boost-sharp_shooting')), findsOneWidget);
      // Only the proactive three: the bench boosts are not here.
      expect(find.byKey(const ValueKey('match-boost-var_review')), findsNothing);
      expect(find.byKey(const ValueKey('match-boost-physio_sponge')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('match-boost-count-crowd_roar'))).data,
        'x2',
      );
      // Nothing pauses: the chips are the control, not a menu.
      expect(state.paused, isFalse);
      await _finish(tester, state);
    });

    testWidgets('AND IS NOT THERE AT ALL DURING THE TUTORIAL', (tester) async {
      // Loaded first: `settleTutorial` finishes the script on any save with
      // cards on the grid, so the flag is put back AFTER the load, the way a
      // tutorial in progress holds it within one session.
      final container = ProviderContainer(
        overrides: [
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({saveKeyPrimary: jsonEncode(_save())}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(gameProvider).load();
      container.read(gameProvider).state!['tutorial'] =
          <String, dynamic>{'done': false, 'step': 3};
      await pumpMatch(tester, _playable(), container: container, instance: 'tut');
      expect(find.byKey(const ValueKey('match-boosts')), findsNothing);
      // Nor can the bench offer either of the other two.
      final state = stateOf(tester);
      expect(state.physioTarget, isNull);
      expect(state.varTarget, isNull);
      await _finish(tester, state);
    });

    testWidgets('AN UNOWNED BOOST READS x0, GREYED, AND DOES NOTHING', (
      tester,
    ) async {
      final c = await pumpMatch(
        tester,
        _playable(),
        save: _save(boosts: const {}),
        instance: 'unowned',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('match-boost-count-crowd_roar'))).data,
        'x0',
      );
      final before = stateOf(tester).resimCount;
      await tester.tap(find.byKey(const ValueKey('match-boost-crowd_roar')));
      await tester.pump();
      // Nothing was spent, nothing re-decided, and no shop was asked for —
      // nothing is for sale on the pitch.
      expect(stateOf(tester).resimCount, before);
      expect(c.read(shellControllerProvider).pendingShopSection, isNull);
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

      await _call(tester, 'crowd_roar');

      expect(boostCount(c.read(gameProvider).state, 'crowd_roar'), 1);
      expect(state.boostWindows.single.id, 'crowd_roar');
      expect(state.boostWindows.single.toMinute, state.frame.minute + 25);
      expect(state.resimCount, 1);
      // On the pitch, not the bar: the aura is what says it is live.
      expect(find.byKey(const ValueKey('match-boost-aura')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-live-glow')), findsOneWidget);
      // No caption under the board for a boost: the lit pill and the feed
      // already say it. A trait switching on still gets one — see below.
      expect(find.byKey(const ValueKey('match-live-source-pill')), findsNothing);
      expect(state.notes.any((n) => n.key == 'boost.roar.live'), isTrue);
      // And the feed's header names it: BOOST · Crowd Roar.
      expect(
        find.text('${t('boost.feed.action')} · ${t('boost.crowd_roar.name')} · ${t('boost.feed.on')}'.toUpperCase()),
        findsWidgets,
      );
      // The split, not the star: the star is an int blended from the already
      // rounded pair, and on a ~15-rated eleven a 10% lift can round away.
      final liftedAtk = state.liveRatings['liveAttackRating'] as num;
      final liftedDef = state.liveRatings['liveDefenceRating'] as num;

      await tester.pump(const Duration(seconds: 3));
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
      expect(find.byKey(const ValueKey('match-boost-aura')), findsNothing);
      expect(state.notes.any((n) => n.key == 'boost.roar.over'), isTrue);
      expect(liftedAtk, greaterThan(state.liveRatings['liveAttackRating'] as num));
      expect(liftedDef, greaterThan(state.liveRatings['liveDefenceRating'] as num));
      await _finish(tester, state);
    });

    testWidgets('PARK THE BUS trims BOTH sides\' ATK, on the board', (
      tester,
    ) async {
      await pumpMatch(tester, _playable(), save: _save(), instance: 'bus');
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      await _call(tester, 'park_the_bus');
      expect(state.boostWindows.single.id, 'park_the_bus');
      expect(find.byKey(const ValueKey('match-boost-aura')), findsOneWidget);
      expect(state.notes.any((n) => n.key == 'boost.bus.live'), isTrue);
      final busAtk = state.liveRatings['liveAttackRating'] as num;
      final busOpp = state.liveRatings['liveOppAttackRating'] as num;
      final busDef = state.liveRatings['liveDefenceRating'] as num;
      await _finish(tester, state);

      await pumpMatch(tester, _playable(), save: _save(), instance: 'plain');
      final plain = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      plain.applyStrategy(strategies.keys.firstWhere((id) => id != plain.strategy));
      await tester.pump();
      expect(busAtk, lessThan(plain.liveRatings['liveAttackRating'] as num));
      expect(busOpp, lessThan(plain.liveRatings['liveOppAttackRating'] as num));
      expect(busDef, plain.liveRatings['liveDefenceRating']);
      await _finish(tester, plain);
    });

    testWidgets('SHARP SHOOTING lifts our ATK alone, and the pitch says so', (
      tester,
    ) async {
      await pumpMatch(
        tester,
        _playable(),
        save: _save(boosts: const {'sharp_shooting': 1}),
        instance: 'sharp',
      );
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      await _call(tester, 'sharp_shooting');
      expect(state.boostWindows.single.id, 'sharp_shooting');
      expect(find.byKey(const ValueKey('match-boost-aura')), findsOneWidget);
      expect(state.notes.any((n) => n.key == 'boost.sharp.live'), isTrue);
      // ATK up on the board, DEF where it was: the lift is one stat only.
      final sharpAtk = state.liveRatings['liveAttackRating'] as num;
      final sharpDef = state.liveRatings['liveDefenceRating'] as num;
      await _finish(tester, state);

      await pumpMatch(tester, _playable(), save: _save(), instance: 'plain2');
      final plain = stateOf(tester);
      await tester.pump(minuteDurationFor(40));
      plain.applyStrategy(strategies.keys.firstWhere((id) => id != plain.strategy));
      await tester.pump();
      expect(sharpAtk, greaterThan(plain.liveRatings['liveAttackRating'] as num));
      expect(sharpDef, plain.liveRatings['liveDefenceRating']);
      await _finish(tester, plain);
    });

    testWidgets('TWO ROARS STACK, and the window runs to the later end', (
      tester,
    ) async {
      await pumpMatch(tester, _playable(), save: _save(), instance: 'stack');
      final state = stateOf(tester);
      await tester.pump(minuteDurationFor(30));
      await _call(tester, 'crowd_roar');
      await _runTo(tester, state, state.frame.minute + 5);
      await _call(tester, 'crowd_roar');
      expect(state.boostWindows.length, 2);
      // The chip says where the later window ends.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('match-boost-until-crowd_roar'))).data,
        contains("${state.boostWindows.last.toMinute}'"),
      );
      await _finish(tester, state);
    });
  });

  group('THE AURA REMEMBERS', () {
    test('a ring keeps its lane when the one outside it ends', () {
      final m = AuraMemory();
      expect(m.laneFor('crowd_roar', ['crowd_roar']), 0);
      expect(m.laneFor('park_the_bus', ['crowd_roar', 'park_the_bus']), 1);
      expect(m.laneFor('sharp_shooting', ['crowd_roar', 'park_the_bus', 'sharp_shooting']), 2);
      // The Roar ends: the other two stay where they were.
      m.keepOnly(['park_the_bus', 'sharp_shooting']);
      expect(m.laneFor('park_the_bus', ['park_the_bus', 'sharp_shooting']), 1);
      expect(m.laneFor('sharp_shooting', ['park_the_bus', 'sharp_shooting']), 2);
      // A new Roar takes the freed outer lane.
      expect(m.laneFor('crowd_roar', ['park_the_bus', 'sharp_shooting', 'crowd_roar']), 0);
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
      await _call(tester, 'crowd_roar');
      await tester.tap(find.byKey(const ValueKey('match-stats-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-active')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-active-crowd_roar')), findsOneWidget);
      // A trait is listed per man, as his card: all eleven wear Fortress.
      expect(find.byKey(const ValueKey('match-active-cards')), findsOneWidget);
      for (var i = 0; i < 11; i++) {
        expect(find.byKey(ValueKey('match-active-fortress-c$i')), findsOneWidget);
      }
      expect(find.textContaining("${state.boostWindows.single.toMinute}'"), findsWidgets);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await _finish(tester, state);
    });
  });
}
