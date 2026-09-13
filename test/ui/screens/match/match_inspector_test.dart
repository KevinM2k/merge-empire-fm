/// The inspector is the positional record opened up: three views of the same
/// twenty zones, every player's duel record, and who met whom — all of it
/// narrowable to one man.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/match_analysis.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_heatmap.dart';
import 'package:merge_empire_fc/ui/screens/match/match_inspector.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

PositionalEvent _ev({
  int m = 10,
  required int z,
  String s = 'ours',
  String p = 'rf',
  String? op = 'ai:lb',
  String t = 'duel',
  String o = 'win',
  double? xg,
}) => PositionalEvent(
  minute: m,
  zone: z,
  side: s,
  playerId: p,
  opponentId: op,
  type: t,
  outcome: o,
  xg: xg,
);

/// Our right winger busy down the right, their striker quiet at the other end,
/// and one shot each so both sides have a figure under every view.
Map<String, dynamic> _record() => positionalSummary([
  _ev(z: zoneIndex(1, 1), p: 'rf', op: 'ai:lb'),
  _ev(z: zoneIndex(1, 1), p: 'rf', op: 'ai:lb'),
  _ev(z: zoneIndex(1, 0), p: 'rf', op: 'ai:lb', o: 'lose'),
  _ev(z: zoneIndex(2, 0), p: 'cf', op: 'ai:lcb', t: 'shot', o: 'goal', xg: 0.4),
  _ev(z: zoneIndex(3, 1), p: 'lf', op: 'ai:rb', o: 'lose'),
  _ev(
    z: zoneIndex(2, 3),
    s: 'theirs',
    p: 'ai:rs',
    op: 'lcb',
    t: 'shot',
    o: 'miss',
    xg: 0.2,
  ),
]);

Future<void> pumpInspector(
  WidgetTester tester, {
  Map<String, dynamic>? positional,
}) async {
  final save = createDefaultState();
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
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
          home: Scaffold(
            body: MatchInspector(
              result: const {'clubName': 'Testville', 'opponentName': 'Ayton'},
              positional: positional ?? _record(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The sheet scrolls, and a `ListView` does not build what is off-screen — so a
/// test about the pairings has to go and find them, exactly as a player does.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

HeatmapPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(find.byKey(const ValueKey('match-heatmap')))
            .painter!
        as HeatmapPainter;

void main() {
  tearDown(resetLocale);

  group('inspectedPlayers', () {
    test('our side first, and an AI player is his slot', () {
      final rows = inspectedPlayers(_record(), null);
      // Ours are most-involved first; `rf` had three duels and nobody else more.
      expect(rows.first.id, 'rf');
      expect(rows.first.ours, isTrue);
      expect(rows.where((r) => r.ours).length, 4);
      final lb = rows.firstWhere((r) => r.id == 'ai:lb');
      expect(lb.ours, isFalse);
      // No card for a pseudo-player, so he is the slot the token would read.
      expect(lb.name, 'LB');
    });

    test('carries the duel record and what he had at goal', () {
      final rows = inspectedPlayers(_record(), null);
      final rf = rows.firstWhere((r) => r.id == 'rf');
      expect((rf.won, rf.lost), (2, 1));
      expect(rf.shots, 0);
      final cf = rows.firstWhere((r) => r.id == 'cf');
      expect(cf.shots, 1);
      expect(cf.xg, closeTo(0.4, 1e-9));
    });

    test('an unknown card falls back to its id rather than a blank row', () {
      final rows = inspectedPlayers(_record(), null);
      // The save in this test has no card called `rf`, so the row is still
      // findable — a sold player must not erase his own line.
      expect(rows.firstWhere((r) => r.id == 'rf').name, 'rf');
    });
  });

  group('the three views', () {
    testWidgets('touches is where it opens, and the grid is the side total', (
      tester,
    ) async {
      await pumpInspector(tester);
      final painter = _painter(tester);
      // Five of our events, one of theirs.
      expect(painter.ours.fold<double>(0, (a, b) => a + b.toDouble()), 5);
      expect(painter.theirs.fold<double>(0, (a, b) => a + b.toDouble()), 1);
      expect(painter.ours[zoneIndex(1, 1)], 2);
    });

    testWidgets('shots narrows to the shots, and xG to their quality', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.byKey(const ValueKey('inspect-metric-shots')));
      await tester.pumpAndSettle();
      var painter = _painter(tester);
      expect(painter.ours.fold<double>(0, (a, b) => a + b.toDouble()), 1);
      expect(painter.ours[zoneIndex(2, 0)], 1);

      await tester.tap(find.byKey(const ValueKey('inspect-metric-xg')));
      await tester.pumpAndSettle();
      painter = _painter(tester);
      expect(painter.ours[zoneIndex(2, 0)], closeTo(0.4, 1e-9));
      expect(painter.theirs[zoneIndex(2, 3)], closeTo(0.2, 1e-9));
    });

    testWidgets('the total line follows the view', (tester) async {
      await pumpInspector(tester);
      final total = find.byKey(const ValueKey('inspect-total'));
      expect(
        tester.widget<Text>(total).data,
        t('match.inspect.total', {
          'metric': t('match.inspect.touches'),
          'ours': '5',
          'theirs': '1',
        }),
      );
      await tester.tap(find.byKey(const ValueKey('inspect-metric-xg')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(total).data,
        t('match.inspect.total', {
          'metric': t('match.inspect.xg'),
          'ours': '0.4',
          'theirs': '0.2',
        }),
      );
    });
  });

  group('one player at a time', () {
    testWidgets('tapping a player leaves only his own map on the pitch', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.byKey(const ValueKey('inspect-player-rf')));
      await tester.pumpAndSettle();
      final painter = _painter(tester);
      // His three events, and nothing of theirs — the other side is blanked
      // rather than left at its full total behind one man's map.
      expect(painter.ours.fold<double>(0, (a, b) => a + b.toDouble()), 3);
      expect(painter.theirs.fold<double>(0, (a, b) => a + b.toDouble()), 0);
      expect(find.byKey(const ValueKey('inspect-showing')), findsOneWidget);
    });

    testWidgets('an AI player is painted in their ink, not ours', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.byKey(const ValueKey('inspect-player-ai:lb')));
      await tester.pumpAndSettle();
      final painter = _painter(tester);
      expect(painter.ours.fold<double>(0, (a, b) => a + b.toDouble()), 0);
      // The full-back met our winger three times, at his end of the pitch.
      expect(painter.theirs.fold<double>(0, (a, b) => a + b.toDouble()), 3);
    });

    testWidgets('tapping him again, or the clear button, gives both sides back', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.byKey(const ValueKey('inspect-player-rf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inspect-player-rf')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inspect-showing')), findsNothing);
      expect(_painter(tester).theirs.fold<double>(0, (a, b) => a + b.toDouble()), 1);

      await tester.tap(find.byKey(const ValueKey('inspect-player-rf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inspect-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inspect-showing')), findsNothing);
    });

    testWidgets('the flank bars narrow with him', (tester) async {
      await pumpInspector(tester);
      await tester.tap(find.byKey(const ValueKey('inspect-player-rf')));
      await tester.pumpAndSettle();
      // Everything he did was in lane 1 — his own right, and the whole of it.
      final shares = gridFlankShares(_painter(tester).ours, theirs: false);
      expect(shares[Flank.right], 1);
      expect(shares[Flank.left], 0);
    });
  });

  group('who met whom', () {
    testWidgets('lists the pairings by name, most contested first', (
      tester,
    ) async {
      await pumpInspector(tester);
      expect(
        find.text(
          t('match.inspect.versus', {'attacker': 'rf', 'defender': 'LB'}),
        ),
        findsOneWidget,
      );
      // NAMES, not ids: their striker reads as his slot and ours as his card.
      expect(
        find.text(
          t('match.inspect.versus', {'attacker': 'RS', 'defender': 'lcb'}),
        ),
        findsOneWidget,
      );
    });

    testWidgets('and narrows to the selected player\'s own pairings', (
      tester,
    ) async {
      await pumpInspector(tester);
      await tester.tap(find.byKey(const ValueKey('inspect-player-rf')));
      await tester.pumpAndSettle();
      final his = find.text(
        t('match.inspect.versus', {'attacker': 'rf', 'defender': 'LB'}),
      );
      await _scrollTo(tester, his);
      expect(his, findsOneWidget);
      // Their striker's pairing is not his business.
      expect(
        find.text(
          t('match.inspect.versus', {'attacker': 'RS', 'defender': 'lcb'}),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('a record with nothing in it still opens', (tester) async {
    await pumpInspector(tester, positional: positionalSummary(const []));
    expect(find.byKey(const ValueKey('match-inspector')), findsOneWidget);
    expect(_painter(tester).ours, List.filled(pitchZones, 0.0));
  });
}
