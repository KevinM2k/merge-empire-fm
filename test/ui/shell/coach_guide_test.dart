/// The onboarding trail, reached the way a player reaches it.
///
/// **A second file for the same reason `coach_tip_host_test` is one.** The
/// engine's rules are pinned next to the engine; this asks whether anybody ever
/// sees one — which is the check that has caught six engines in this port,
/// fully ported, fully tested, never called.
///
/// The shell's harness is `coach_tip_host_test.dart`'s `pumpShell`: a save with
/// the script finished and today's reward already claimed, so nothing is
/// queued over the thing under test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/coach_guide_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

import 'coach_tip_host_test.dart' show pumpShell, settleSave;

void main() {
  tearDown(resetLocale);
  setUp(resetPopupQueue);

  Finder nudge(String tab) => find.byKey(ValueKey('tab-nudge-$tab'));

  testWidgets('THE BAR POINTS AT PLAYERS THE MOMENT THE SCRIPT ENDS', (
    tester,
  ) async {
    // The whole reason the trail exists: the script hands the player back on
    // the home screen with the borrowed eleven just taken off them, and nothing
    // on that screen says the squad is somewhere else.
    final container = await pumpShell(tester, mutate: armCoachGuides);
    addTearDown(container.dispose);

    expect(nudge('grid'), findsOneWidget, reason: 'nothing pointed anywhere');
    // And ONE of them. A bar with two rings in it is a bar pointing nowhere.
    for (final other in const ['squad', 'home', 'club', 'shop']) {
      expect(nudge(other), findsNothing);
    }
  });

  testWidgets('a save that never saw the script finish is left alone', (
    tester,
  ) async {
    // `settleTutorial` marks every save written before the port had a tutorial
    // as done, so this is nearly every save in the wild.
    final container = await pumpShell(tester);
    addTearDown(container.dispose);
    for (final tab in const ['grid', 'squad', 'home', 'club', 'shop']) {
      expect(nudge(tab), findsNothing);
    }
  });

  testWidgets('GOING THERE IS WHAT PUTS IT OUT, AND IT STAYS OUT', (
    tester,
  ) async {
    final container = await pumpShell(tester, mutate: armCoachGuides);
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const ValueKey('tab-grid')));
    await tester.pumpAndSettle();
    expect(nudge('grid'), findsNothing);
    expect(
      container.read(gameProvider).state?['seenTips'],
      contains('guide.players_tab'),
      reason: 'arriving did not spend the marker',
    );

    // Back to Play and out again: a marker that came back would be the app not
    // remembering, which is the one thing this must never do.
    await tester.tap(find.byKey(const ValueKey('tab-home')));
    await tester.pumpAndSettle();
    expect(nudge('grid'), findsNothing);
    await settleSave(tester);
  });

  testWidgets('Colin says it on the tab the player is standing on', (
    tester,
  ) async {
    final container = await pumpShell(tester, mutate: armCoachGuides);
    addTearDown(container.dispose);

    // The Shop is not where the marker points, which is exactly why he has to
    // say it there: a player who has wandered off is the one who needs telling.
    await tester.tap(find.byKey(const ValueKey('tab-shop')));
    await tester.pumpAndSettle();
    expect(nudge('grid'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('coach-floating-head')));
    await tester.pumpAndSettle();
    expect(
      find.text(t('guide.players_tab')),
      findsOneWidget,
      reason: 'his bubble had his usual commentary instead of the trail',
    );
    await settleSave(tester);
  });

  testWidgets('the Dugout opening spends its own marker', (tester) async {
    // Neither the Dugout nor a training session is a tab, so the bar can never
    // report either — they arrive on the bus. See `app_shell.dart`.
    final container = await pumpShell(tester, mutate: (s) {
      armCoachGuides(s);
      for (final id in const ['players_tab', 'squad_tab']) {
        (s['seenTips'] as List).add(guideLedgerId(id));
      }
    });
    addTearDown(container.dispose);
    expect(nudge('home'), findsNothing, reason: 'already on the home tab');

    await tester.tap(find.byKey(const ValueKey('dock-menu')));
    await tester.pumpAndSettle();
    expect(
      container.read(gameProvider).state?['seenTips'],
      contains('guide.dugout'),
    );
    await settleSave(tester);
  });
}
