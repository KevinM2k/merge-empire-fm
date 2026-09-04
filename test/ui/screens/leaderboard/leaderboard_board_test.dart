/// The board's three questions, in one row.
///
/// They were three labelled segment strips stacked down the page, each one
/// scrolling sideways because four metrics in ten languages do not fit across a
/// phone — three rows of chrome above a ranked list. Reported as wanting one row
/// of dropdowns instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/leaderboard_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/leaderboard/leaderboard_board.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

Future<void> pumpBoard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: const Scaffold(
          body: SingleChildScrollView(child: LeaderboardBoard()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('THREE DROPDOWNS, SIDE BY SIDE', (tester) async {
    await pumpBoard(tester);
    for (final key in [
      'leaderboard-metric',
      'leaderboard-period',
      'leaderboard-scope',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    // One row means one line: all three sit at the same height.
    final tops = [
      for (final key in [
        'leaderboard-metric',
        'leaderboard-period',
        'leaderboard-scope',
      ])
        tester.getTopLeft(find.byKey(ValueKey(key))).dy,
    ];
    expect(tops.toSet(), hasLength(1), reason: 'the pickers are still stacked');
  });

  testWidgets('and every metric is reachable inside one of them', (
    tester,
  ) async {
    await pumpBoard(tester);
    await tester.tap(find.byKey(const ValueKey('leaderboard-metric')));
    await tester.pumpAndSettle();
    for (final metric in leaderboardMetrics) {
      expect(
        find.text(t('leaderboard.metric_$metric')),
        findsWidgets,
        reason: metric,
      );
    }
  });

  testWidgets('THE SCOPE PICKER OFFERS THE TWO REACHES, and no more', (
    tester,
  ) async {
    // The division pair read "My Division" and "My Division · Global", and the
    // second is wider than a third of a phone — so it arrived as an ellipsis
    // with no way to tell what it was. Reported from the couch, then directly:
    // we do not need those other two. The policy still resolves all four, and
    // `leaderboard_policy_test` still pins the JS's set at four.
    await pumpBoard(tester);
    final scope = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-scope')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(scope.items, hasLength(2));
    expect(scope.items!.map((i) => i.value), ['all_regional', 'all_global']);
  });

  testWidgets('PRESTIGE FORCES ALL-TIME, and the period says so', (
    tester,
  ) async {
    // Dead rather than hidden: a control that vanishes reads as a missing
    // feature.
    await pumpBoard(tester);
    await tester.tap(find.byKey(const ValueKey('leaderboard-metric')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('leaderboard.metric_prestige')).last);
    await tester.pumpAndSettle();

    // **AND IT SAYS SO BY BEING DEAD, not by explaining itself underneath.**
    // `leaderboard.prestige_hint` wrapped to two lines under a control in a
    // three-across row and restated the greyed-out value above it. Reported
    // from the couch as not knowing what it meant and not needing it.
    expect(find.text(t('leaderboard.prestige_hint')), findsNothing);
    final period = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('leaderboard-period')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(period.onChanged, isNull, reason: 'the period is still pickable');
    expect(period.value, 'alltime');
  });
}
