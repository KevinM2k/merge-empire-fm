/// The tutorial, on screen.
///
/// **The copy was never the blocker; the choreography was**, and it is a port
/// of `Tutorial.js`'s own `STEPS` rather than a reconstruction. This is the
/// half that proves a player can actually be walked through it.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_overlay.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> save({int step = 0, int cards = 0}) {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)
    ..['step'] = step
    ..['done'] = false;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < cards; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': 'player_t1_mid',
      'instanceId': 'own$i',
      'variant': 0,
    };
  }
  return s;
}

Future<ProviderContainer> pumpHost(
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
  // Through `load()` like everything else. `settleTutorial` no longer marks a
  // save finished unconditionally — it settles only one with EVIDENCE OF PLAY,
  // which is what lets a genuinely new save run the script at all. A fixture
  // with cards on the grid is a played save and will be settled, so the ones
  // that need a live tutorial set the step by hand afterwards.
  container.read(gameProvider).load();
  final tut =
      container.read(gameProvider).state!['tutorial'] as Map<String, dynamic>;
  final want = (state['tutorial'] as Map<String, dynamic>);
  tut
    ..['step'] = want['step']
    ..['done'] = want['done']
    ..['borrowedPlayersAdded'] = want['borrowedPlayersAdded']
    ..['borrowedPlayersRemoved'] = want['borrowedPlayersRemoved'];

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: TutorialHost()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Every write arms the 2s debounced save; a test that walks away leaves it
/// pending and the binding rightly complains.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

Future<void> tapAction(WidgetTester tester, String labelKey) async {
  await tester.tap(find.byKey(ValueKey('coach-action-$labelKey')));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(resetLocale);

  testWidgets('IT OPENS ON THE WELCOME, and names the club and the coins', (
    tester,
  ) async {
    final c = await pumpHost(tester, save());
    expect(find.text(t('tut.welcome.title')), findsOneWidget);
    // A placeholder left standing is the whole class of bug the pooled coach
    // copy taught this repo about.
    expect(find.textContaining('{'), findsNothing);
    await tapAction(tester, 'tut.welcome.btn');
    expect((c.read(gameProvider).state!['tutorial'] as Map)['step'], 1);
    await settleSave(tester);
  });

  testWidgets('A STEP WAITING ON THE SAVE SAYS SO, and has no button', (
    tester,
  ) async {
    // Either a button or a condition, never both — and a card with neither
    // would read as one whose button had failed to load.
    await pumpHost(tester, save(step: 1));
    expect(find.text(t('tut.scout_1.title')), findsOneWidget);
    expect(find.text(t('tut.complete_above')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('coach-action-tut.welcome.btn')),
      findsNothing,
    );
    await tapAction(tester, 'tut.skip');
    await settleSave(tester);
  });

  testWidgets('THE LOAN STEP LENDS A SIDE when it is answered', (tester) async {
    final c = await pumpHost(tester, save(step: 3, cards: 3));
    expect(find.text(t('tut.loan_boost.title')), findsOneWidget);
    await tapAction(tester, 'tut.loan_boost.btn');

    final cells =
        (c.read(gameProvider).state!['grid'] as Map<String, dynamic>)['cells']
            as List;
    expect(
      cells.where((x) => (x as Map?)?['borrowed'] == true),
      isNotEmpty,
      reason: 'nobody was lent',
    );
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
  });

  testWidgets('AND THE DEPARTURE TAKES THEM BACK AND PAYS', (tester) async {
    final state = save(step: 3, cards: 3);
    lendTutorialPlayers(state);
    (state['tutorial'] as Map<String, dynamic>)['step'] = 7;
    final c = await pumpHost(tester, state);
    final before =
        ((c.read(gameProvider).state!['resources'] as Map)['fanCoins'] as num)
            .toInt();

    expect(find.text(t('tut.loan_depart.title')), findsOneWidget);
    await tapAction(tester, 'tut.loan_depart.btn');

    final after = c.read(gameProvider).state!;
    final cells = (after['grid'] as Map<String, dynamic>)['cells'] as List;
    expect(cells.where((x) => (x as Map?)?['borrowed'] == true), isEmpty);
    expect(
      ((after['resources'] as Map)['fanCoins'] as num).toInt() - before,
      tutorialFarewellCoins,
    );
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
  });

  testWidgets('SKIP ENDS IT AT ANY STEP, and leaves what was lent', (
    tester,
  ) async {
    // The step that takes them back also pays the 500, so a player who skips
    // between the two has been lent a side rather than robbed of one.
    final state = save(step: 3, cards: 3);
    lendTutorialPlayers(state);
    (state['tutorial'] as Map<String, dynamic>)['step'] = 4;
    final c = await pumpHost(tester, state);
    await tapAction(tester, 'tut.skip');

    final after = c.read(gameProvider).state!;
    expect((after['tutorial'] as Map)['done'], isTrue);
    final cells = (after['grid'] as Map<String, dynamic>)['cells'] as List;
    expect(cells.where((x) => (x as Map?)?['borrowed'] == true), isNotEmpty);
    expect(find.text(t('tut.play_match.title')), findsNothing);
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
  });

  testWidgets('A FINISHED SAVE SHOWS NOTHING AT ALL', (tester) async {
    final state = save();
    (state['tutorial'] as Map<String, dynamic>)['done'] = true;
    await pumpHost(tester, state);
    expect(find.text(t('tut.welcome.title')), findsNothing);
  });

  testWidgets('the reaction step reads the RESULT, not the first-match line', (
    tester,
  ) async {
    final state = save(step: 6);
    (state['progression'] as Map<String, dynamic>)['lastMatchResult'] =
        <String, dynamic>{'won': true, 'score': '2-0'};
    await pumpHost(tester, state);
    expect(find.text(t('tut.match_reaction.win_title')), findsOneWidget);
    expect(find.textContaining('2-0'), findsOneWidget);
    await tapAction(tester, 'tut.skip');
    await settleSave(tester);
  });

  testWidgets('and it is in the player\'s language', (tester) async {
    setLocale('de');
    await pumpHost(tester, save());
    expect(find.textContaining('tut.'), findsNothing);
    await tapAction(tester, 'tut.skip');
    await settleSave(tester);
  });
}
