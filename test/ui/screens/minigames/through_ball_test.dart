/// Through Ball — the timing bar.
///
/// `recordThroughBallResult` and `throughBallDifficulty` have been ported and
/// tested since M1; the row in the Training tab said "coming soon" over them,
/// and `game.throughball.score`, `mg.tap_green`, `mg.hit`, `mg.miss` and
/// `mg.hits` were shipped in all ten catalogues with nothing able to reach one.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/screens/minigames/through_ball_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> saveWith({String? division}) {
  final s = createDefaultState();
  // Tier 3 Training Ground, which is the rung Through Ball sits on.
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 3,
    'invested': 0,
    'tapCount': 0,
  };
  if (division != null) {
    (s['progression'] as Map<String, dynamic>)['currentDivision'] = division;
  }
  return s;
}

Future<ProviderContainer> pumpGame(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const ThroughBallScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

ThroughBallScreenState stateOf(WidgetTester tester) =>
    tester.state<ThroughBallScreenState>(find.byType(ThroughBallScreen));

/// Tear the screen down and settle the debounced save.
///
/// Leaving BANKS — that is the JS's rule — so every test ends with a write, and
/// a write arms the two-second debounce. Letting the harness dispose the tree
/// on its own leaves that timer pending and the binding rightly complains.
Future<void> closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

/// Tap, wait out the 700ms feedback beat, and land on the next round.
Future<void> playRound(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('through-ball-screen')));
  await tester.pump();
  await tester.pump(throughBallFeedback + const Duration(milliseconds: 20));
}

void main() {
  tearDown(resetLocale);

  group('the sweep', () {
    test('is a PING-PONG, not a wrap', () {
      // A sawtooth would snap the marker across the whole bar every cycle and
      // the tap window would be a different shape at each end.
      expect(markerPctAt(0, 1000), closeTo(0, 0.001));
      expect(markerPctAt(250, 1000), closeTo(50, 0.001));
      expect(markerPctAt(500, 1000), closeTo(100, 0.001));
      expect(markerPctAt(750, 1000), closeTo(50, 0.001));
      expect(markerPctAt(1000, 1000), closeTo(0, 0.001));
    });

    test('and it never leaves the track', () {
      for (var ms = 0; ms < 4000; ms += 7) {
        final at = markerPctAt(ms.toDouble(), 900);
        expect(at, inInclusiveRange(0, 100), reason: '$ms');
      }
    });
  });

  group('the zone', () {
    test('SHRINKS every round, with a floor', () {
      final base = throughBallDifficulty(0).zonePct;
      final widths = [
        for (var r = 0; r < ThroughBall.rounds; r++)
          throughBallZone(r, base, 0.5).width,
      ];
      for (var i = 1; i < widths.length; i++) {
        expect(widths[i], lessThan(widths[i - 1]), reason: 'round $i');
      }
      // 40% of base on the last round — the floor is 35%, which only bites if
      // the session is ever made longer than five.
      expect(widths.last, closeTo(base * 0.4, 0.001));
      expect(throughBallZone(9, base, 0.5).width, closeTo(base * 0.35, 0.001));
    });

    test('and it always FITS on the track, at either extreme', () {
      for (final divIdx in [0, 3, 6]) {
        final base = throughBallDifficulty(divIdx).zonePct;
        for (var r = 0; r < ThroughBall.rounds; r++) {
          for (final roll in [0.0, 0.5, 1.0]) {
            final z = throughBallZone(r, base, roll);
            expect(z.lo, greaterThanOrEqualTo(-0.001), reason: '$divIdx/$r');
            expect(z.hi, lessThanOrEqualTo(100.001), reason: '$divIdx/$r');
          }
        }
      }
    });

    test('is TIGHTER and the sweep QUICKER as you climb', () {
      final sunday = throughBallDifficulty(0);
      final champions = throughBallDifficulty(divisions.length - 1);
      expect(champions.zonePct, lessThan(sunday.zonePct));
      expect(champions.sweepMs, lessThan(sunday.sweepMs));
    });
  });

  testWidgets('the drill is REACHABLE — it is in the playable set', (
    tester,
  ) async {
    expect(playableMiniGames, contains(MiniGameKind.throughBall));
  });

  testWidgets('entering starts the cooldown, not finishing', (tester) async {
    // Walking away mid-session must not farm the reward timer.
    final container = await pumpGame(tester, saveWith());
    await tester.pump();
    final save = container.read(gameProvider).state!;
    expect(miniGameReady(save, MiniGameKind.throughBall), isFalse);
    await closeGame(tester);
  });

  testWidgets('A TAP INSIDE THE ZONE SCORES, and one outside does not', (
    tester,
  ) async {
    await pumpGame(tester, saveWith());
    await tester.pump();
    final s = stateOf(tester);

    // The marker is model state the sweep writes and the tap reads — so a test
    // can place it, which is the same seam the JS lost when it started parsing
    // the element's `left` and scored a miss on every tap.
    s.placeMarker((s.zoneLo + s.zoneHi) / 2);
    await playRound(tester);
    expect(s.passed, 1);
    expect(s.round, 1);

    s.placeMarker(s.zoneLo > 1 ? 0 : 100);
    await playRound(tester);
    expect(s.passed, 1, reason: 'a miss was counted as a hit');
    expect(s.round, 2);
    await closeGame(tester);
  });

  testWidgets('ALL FIVE LANES ARE ON SCREEN FROM THE FIRST FRAME', (
    tester,
  ) async {
    // One track was drawn at a time and replaced between rounds, which spends a
    // whole screen of empty space to show a session one fifth at a time. Asked
    // for as five lanes stacked, the top one first, and nothing below it
    // starting until the one above is finished.
    await pumpGame(tester, saveWith());
    await tester.pump();
    final s = stateOf(tester);

    for (var lane = 0; lane < ThroughBall.rounds; lane++) {
      expect(
        find.byKey(ValueKey('tb-lane-$lane')),
        findsOneWidget,
        reason: 'lane $lane is not on screen',
      );
      expect(
        find.byKey(ValueKey('tb-zone-$lane')),
        findsOneWidget,
        reason: 'lane $lane has no green to aim at yet',
      );
    }
    // Only the top lane is running.
    expect(find.byKey(const ValueKey('tb-marker-0')), findsOneWidget);
    for (var lane = 1; lane < ThroughBall.rounds; lane++) {
      expect(find.byKey(ValueKey('tb-marker-$lane')), findsNothing);
    }

    // And the green NARROWS down the stack, which is the difficulty curve made
    // visible: 100% → 85% → 70% → 55% → 40% of the division's width.
    final widths = [
      for (var lane = 0; lane < ThroughBall.rounds; lane++)
        tester.getRect(find.byKey(ValueKey('tb-zone-$lane'))).width,
    ];
    for (var lane = 1; lane < widths.length; lane++) {
      expect(widths[lane], lessThan(widths[lane - 1]), reason: 'lane $lane');
    }

    // Playing the top lane hands the marker to the second and leaves the
    // first's where it stopped.
    s.placeMarker((s.zoneLo + s.zoneHi) / 2);
    await playRound(tester);
    expect(find.byKey(const ValueKey('tb-marker-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tb-marker-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tb-marker-2')), findsNothing);
    await closeGame(tester);
  });

  testWidgets('five rounds, then the summary and the coins', (tester) async {
    final container = await pumpGame(tester, saveWith());
    await tester.pump();
    final s = stateOf(tester);

    for (var i = 0; i < ThroughBall.rounds; i++) {
      s.placeMarker((s.zoneLo + s.zoneHi) / 2);
      await playRound(tester);
    }
    await tester.pumpAndSettle();

    expect(s.passed, ThroughBall.rounds);
    expect(s.over, isTrue);
    expect(
      find.text('${ThroughBall.rounds}/${ThroughBall.rounds}'),
      findsOneWidget,
    );

    final before =
        (container.read(gameProvider).state!['resources']
            as Map<String, dynamic>)['fanCoins'];
    await tester.tap(find.byKey(const ValueKey('tb-collect')));
    await tester.pump();
    final after =
        (container.read(gameProvider).state!['resources']
            as Map<String, dynamic>)['fanCoins'];
    expect(
      (after as num) - (before as num),
      greaterThan(0),
      reason: 'a perfect session paid nothing',
    );
    await tester.pumpAndSettle();
    await closeGame(tester);
  });

  testWidgets('CLOSING IS NOT A FORFEIT — the rounds played are banked', (
    tester,
  ) async {
    // The JS banks on the way out for exactly this reason: three good rounds
    // and a phone call should not cost the player three good rounds.
    final container = await pumpGame(tester, saveWith());
    await tester.pump();
    final s = stateOf(tester);
    s.placeMarker((s.zoneLo + s.zoneHi) / 2);
    await playRound(tester);
    expect(s.passed, 1);

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(after - before, greaterThan(0));
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

  });

  testWidgets('and it is banked ONCE, not once per exit', (tester) async {
    final container = await pumpGame(tester, saveWith());
    await tester.pump();
    final s = stateOf(tester);
    for (var i = 0; i < ThroughBall.rounds; i++) {
      s.placeMarker((s.zoneLo + s.zoneHi) / 2);
      await playRound(tester);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tb-collect')));
    await tester.pump();
    final afterCollect =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final afterClose =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(afterClose, afterCollect, reason: 'the session paid twice');
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  });
}
