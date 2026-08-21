/// The table, moving, at full time.
///
/// The block's whole claim is that it shows where the division WAS and then
/// rearranges it, so the tests are about the two frames either side of the
/// hold — and about the case where there is no honest "before" to open on.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart' show saveDebounceMs;
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/match/summary_league_move.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// Pump the block over a save, with animations LIVE — this widget is about
/// movement, so the harness's usual reduced-motion default would test the one
/// path that has none.
Future<ProviderContainer> pumpMove(
  WidgetTester tester, {
  void Function(Map<String, dynamic>)? mutate,
  bool reducedMotion = false,
}) async {
  final state = createDefaultState();

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameRunnerProvider).boot();
  if (mutate != null) container.read(gameProvider).update(mutate);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: const Scaffold(
            body: Center(child: SizedBox(width: 360, child: LeagueMove())),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Play a round, so the table has a previous one to have moved from.
///
/// `seasonAwardedPlayed` is what `buildLeagueTable` counts, and the movement
/// snapshot only rolls over for the round IMMEDIATELY before this one — so the
/// table has to be BUILT at the earlier round for a "before" to exist at all.
void playRounds(ProviderContainer container, {required int upTo}) {
  for (var round = 1; round <= upTo; round++) {
    container.read(gameProvider).update((s) {
      final prog = s['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = round;
      prog['seasonWins'] = round;
      prog['seasonDraws'] = 0;
    });
    // Reading it is what stamps the snapshot: the engine tracks movement
    // between RENDERS, which is the same reason the next-match card can show a
    // delta at all.
    container.read(leagueTableProvider);
  }
}

/// Let the save's debounce fire. Every `update` here schedules one, and a
/// timer still pending when the tree goes down fails the test on a fault that
/// belongs to the harness rather than to the block.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

/// Where each row sits in the block right now, top first.
List<String> orderOnScreen(WidgetTester tester) {
  final rows = tester.widgetList<AnimatedPositioned>(
    find.byType(AnimatedPositioned),
  );
  final placed = [
    for (final row in rows)
      (top: row.top ?? 0, name: (row.key! as ValueKey<String>).value),
  ]..sort((a, b) => a.top.compareTo(b.top));
  return [
    for (final row in placed) row.name.replaceFirst('summary-table-', ''),
  ];
}

void main() {
  testWidgets('IT OPENS ON THE TABLE AS IT WAS, then moves', (tester) async {
    final container = await pumpMove(tester);
    playRounds(container, upTo: 1);
    // The round the summary is being shown for: won, so we climb.
    container.read(gameProvider).update((s) {
      final prog = s['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = 2;
      prog['seasonWins'] = 2;
    });
    await tester.pump();

    final settled = container.read(leagueTableProvider);
    final before = orderOnScreen(tester);
    expect(before, isNotEmpty);
    expect(
      before,
      isNot([for (final row in settled) row.name]),
      reason: 'the block opened on the settled table, with nothing to show',
    );
    // Where every club stood at the end of the previous round.
    expect(before, [
      for (final row
          in (settled.toList()
            ..sort((a, b) => a.prevPos!.compareTo(b.prevPos!))))
        row.name,
    ]);

    await tester.pump(leagueMoveHold);
    await tester.pumpAndSettle();
    expect(orderOnScreen(tester), [
      for (final row in settled) row.name,
    ], reason: 'the table never moved');
    expect(
      tester.state<LeagueMoveState>(find.byType(LeagueMove)).moved,
      isTrue,
    );
    await settleSave(tester);
  });

  testWidgets('and it says which way WE went', (tester) async {
    final container = await pumpMove(tester);
    playRounds(container, upTo: 1);
    container.read(gameProvider).update((s) {
      final prog = s['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = 2;
      prog['seasonWins'] = 2;
    });
    await tester.pump();

    final ours = container
        .read(leagueTableProvider)
        .firstWhere((r) => r.isPlayer);
    expect(ours.posDelta, isNotNull);
    // No arrow while the old table is still up: it would give away the
    // rearrangement it is there to explain.
    expect(
      tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity,
      0,
    );

    await tester.pump(leagueMoveHold);
    await tester.pumpAndSettle();
    final key = switch (ours.posDelta!) {
      > 0 => 'summary-table-climbed',
      < 0 => 'summary-table-fell',
      _ => 'summary-table-held',
    };
    expect(find.byKey(ValueKey(key)), findsOneWidget);
    await settleSave(tester);
  });

  testWidgets('A ROUND IT CANNOT COMPARE AGAINST CLAIMS NO MOVEMENT', (
    tester,
  ) async {
    // The engine clears the previous positions whenever they would be a lie —
    // a season rollover, or a round the table was never built during. Half a
    // movement is worse than none.
    final container = await pumpMove(tester);
    container.read(gameProvider).update((s) {
      final prog = s['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = 3;
      prog['seasonWins'] = 3;
    });
    await tester.pump();

    final settled = container.read(leagueTableProvider);
    expect(settled.every((r) => r.prevPos == null), isTrue);
    expect(orderOnScreen(tester), [for (final row in settled) row.name]);
    expect(find.byType(AnimatedOpacity), findsNothing);
    await settleSave(tester);
  });

  testWidgets('reduced motion gets the answer without the movement', (
    tester,
  ) async {
    final container = await pumpMove(tester, reducedMotion: true);
    playRounds(container, upTo: 1);
    container.read(gameProvider).update((s) {
      final prog = s['progression'] as Map<String, dynamic>;
      prog['seasonAwardedPlayed'] = 2;
      prog['seasonWins'] = 2;
    });
    await tester.pump();

    // Settled from the first frame, and the deltas are up: they are
    // information, not decoration.
    expect(orderOnScreen(tester), [
      for (final row in container.read(leagueTableProvider)) row.name,
    ]);
    expect(
      tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity,
      1,
    );
    await settleSave(tester);
  });
}
