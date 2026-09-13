/// **A SCREENSHOT TOOL, not part of the suite.** Run it by name:
///
///   flutter test test/screenshots/match_screens.dart --update-goldens
///
/// It writes PNGs to `test/screenshots/out/` (git-ignored) so a change to the
/// match analysis surfaces can be LOOKED AT rather than described. The file
/// deliberately does not end in `_test.dart`, so `flutter test` never picks it
/// up: a pixel comparison across engine versions and font stacks is a flaky
/// test, and these images are evidence for a human, not a regression net. The
/// nets are `match_inspector_test.dart` and `match_heatmap_test.dart`.
///
/// **The fonts are loaded by hand.** A widget test renders with a test font
/// whose glyphs are empty boxes, so an un-Fontloaded capture is a picture of a
/// layout with no words in it. Barlow and Lilita One are bundled in
/// `assets/fonts/` for the same reason the app uses them — a scoreline the same
/// shape on every phone — so the capture reads them straight off disk.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/match_analysis.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/migration.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_heatmap.dart';
import 'package:merge_empire_fc/ui/screens/match/match_inspector.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// Load the app's own faces so the capture has words in it.
Future<void> loadFonts() async {
  for (final family in const {
    'Barlow': [
      'assets/fonts/Barlow-Regular.ttf',
      'assets/fonts/Barlow-Medium.ttf',
      'assets/fonts/Barlow-SemiBold.ttf',
      'assets/fonts/Barlow-Bold.ttf',
      'assets/fonts/Barlow-ExtraBold.ttf',
      'assets/fonts/Barlow-Black.ttf',
    ],
    'LilitaOne': ['assets/fonts/LilitaOne-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }
}

/// A real match, played through the positional sim — OUR ELEVEN, off the save's
/// own cards and lineup, against a 4-4-2 whose LEFT-BACK is the weak link, so
/// the heatmap has something to say and the player list has real names in it.
///
/// Our side is built the way `simulateMatch` builds it rather than as eleven
/// pseudo-players: a screenshot of the inspector with `ai:` ids on both sides
/// showed every row in the opposition's colour, which is a picture of the
/// harness and not of the screen.
Map<String, dynamic> playedMatch(Map<String, dynamic>? save) {
  seeded.setSeed(11);
  final cells = [
    for (final raw in (_map(save?['grid'])?['cells'] as List? ?? const []))
      ?CardInstance.from(raw),
  ];
  final lineup = [
    for (final raw in (_map(save?['squad'])?['lineup'] as List? ?? const []))
      if (raw is Map<String, dynamic>) raw,
  ];
  final slots = getFormation(
    _map(save?['squad'])?['formation'] as String?,
  ).slots;
  final ours = lineup.isEmpty
      ? pitchSideForAi(74, '4-3-3', mirrored: false)
      : pitchSideFromLineup(
          cards: cells,
          lineup: lineup,
          slots: slots,
        ).scaledToTeam(attack: 74, defence: 70);
  final base = pitchSideForAi(66, '4-4-2');
  final them = PitchSide([
    for (final p in base.players)
      if (p.slotId == 'lb')
        PitchPlayer(
          id: p.id,
          slotId: p.slotId,
          slotPosition: p.slotPosition,
          name: p.name,
          attack: p.attack,
          defence: 48,
          attacking: p.attacking,
          defending: p.defending,
        )
      else
        p,
  ]);
  final out = <PositionalEvent>[];
  positionalWindowGoals(
    ctx: SequenceContext(attackers: ours, defenders: them, side: 'ours'),
    lambda: goalRateLambda(ours.teamMeans.attack, them.teamMeans.defence),
    fromMinute: 0,
    toMinute: 90,
    out: out,
  );
  positionalWindowGoals(
    ctx: SequenceContext(attackers: them, defenders: ours, side: 'theirs'),
    lambda: goalRateLambda(them.teamMeans.attack, ours.teamMeans.defence),
    fromMinute: 0,
    toMinute: 90,
    out: out,
  );
  return positionalSummary(out);
}

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// **A FRESH SAVE HAS NOBODY IN IT.** The migration writes eleven lineup slots
/// and thirty-nine empty grid cells; every `cardInstanceId` is null, so a
/// screenshot taken off it fields no side at all and the inspector comes out
/// with the opposition's colour on every row. This puts a squad on the grid and
/// in the lineup, which is also what makes the player list read as names.
Map<String, dynamic> fieldAnEleven(Map<String, dynamic> save) {
  final slots = getFormation(
    _map(save['squad'])?['formation'] as String?,
  ).slots;
  final cells = (_map(save['grid'])?['cells'] as List?) ?? [];
  final lineup = (_map(save['squad'])?['lineup'] as List?) ?? [];
  for (var i = 0; i < slots.length && i < cells.length; i++) {
    final slot = slots[i];
    final id = 'p${i + 1}';
    cells[i] = {
      'instanceId': id,
      // A spread of tiers so eleven cards are eleven NAMES: one definition per
      // position gives one name per position, and a screenshot of three
      // identical centre-backs reads as a bug in the list.
      'definitionId':
          'player_t${3 + (i % 5)}_${slot.slotPosition.toLowerCase()}',
    };
    for (final raw in lineup) {
      if (raw is Map && raw['slotId'] == slot.slotId) {
        raw['cardInstanceId'] = id;
      }
    }
  }
  return save;
}

const Map<String, dynamic> _result = {
  'clubName': 'Testville',
  'opponentName': 'Ayton Rovers',
};

void main() {
  setUpAll(loadFonts);

  /// One capture, on a 400×860 phone in the kit's dark theme.
  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget Function(Map<String, dynamic> positional) build, {
    Size size = const Size(400, 860),
    Future<void> Function(WidgetTester tester, Map<String, dynamic> positional)?
    after,
  }) async {
    // **`physicalSize` IS IN PHYSICAL PIXELS.** Passing the logical size here
    // renders the screen at half the width at DPR 2, which cramps every row and
    // invents overflows that do not exist on the phone. Multiply.
    const dpr = 2.0;
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final save = fieldAnEleven(migrate(createDefaultState())!);
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(save)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(gameProvider).load();
    final positional = playedMatch(container.read(gameProvider).state);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: Scaffold(body: SafeArea(child: build(positional))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (after != null) await after(tester, positional);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/$name.png'),
    );
  }

  testWidgets('the summary card', (tester) async {
    await shoot(
      tester,
      '01-summary-card',
      (p) => Center(
        child: PositionalCard(result: {..._result, 'positional': p}),
      ),
      size: const Size(400, 420),
    );
  });

  testWidgets('the inspector, touches', (tester) async {
    await shoot(
      tester,
      '02-inspector-touches',
      (p) => MatchInspector(result: _result, positional: p),
    );
  });

  testWidgets('the inspector, expected goals by zone', (tester) async {
    await shoot(
      tester,
      '03-inspector-xg',
      (p) => MatchInspector(result: _result, positional: p),
      after: (tester, p) async {
        await tester.tap(find.byKey(const ValueKey('inspect-metric-xg')));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('the inspector, one player only', (tester) async {
    await shoot(
      tester,
      '04-inspector-one-player',
      (p) => MatchInspector(result: _result, positional: p),
      after: (tester, p) async {
        // Whoever the match actually gave the ball to most.
        final busiest = busiestDuellist(p)!;
        final row = find.byKey(ValueKey('inspect-player-${busiest.id}'));
        await tester.scrollUntilVisible(
          row,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        // Back to the top, so the capture shows his map and not the list.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
        await tester.pumpAndSettle();
      },
    );
  });
}
