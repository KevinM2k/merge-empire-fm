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
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart' show matchPopupBlocker;
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/loan_arrival.dart';
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
  Map<String, dynamic> state, {
  /// **A step that ANIMATES cannot be settled into.** `loan_depart` flies the
  /// loan off the grid before it says a word, and `pumpAndSettle` walks the
  /// clock straight past it — so the one test about that window asks for the
  /// frames by hand.
  bool settle = true,
}) async {
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
  if (settle) await tester.pumpAndSettle();
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

/// **SKIP IS A LINK UNDER THE BUTTON, not a button beside it.** Leaving and
/// getting on with it are not two answers of equal weight, and as a pair of
/// halves "Let's go" was half a card wide.
Future<void> tapFooter(WidgetTester tester, String labelKey) async {
  await tester.tap(find.byKey(ValueKey('coach-footer-$labelKey')));
  await tester.pumpAndSettle();
}

/// The index of a step by ID.
///
/// **THE SCRIPT GREW A STEP and every `save(step: N)` in this file went stale
/// silently.** `step: 3` was the loan boost when these were written and is the
/// MERGE step now, so six tests were driving the wrong card and failing on a
/// button that was never on screen. An index into a list of ten is a fixture
/// with a shelf life; the id is what the test means.
int stepAt(String id) => tutorialSteps.indexWhere((s) => s.id == id);

void main() {
  tearDown(resetLocale);

  testWidgets('IT OPENS ON THE WELCOME, and names the club and the coins', (
    tester,
  ) async {
    final c = await pumpHost(tester, save());
    expect(find.text(withoutEmoji(t('tut.welcome.title'))), findsOneWidget);
    // A placeholder left standing is the whole class of bug the pooled coach
    // copy taught this repo about.
    expect(find.textContaining('{'), findsNothing);
    await tapAction(tester, 'tut.welcome.btn');
    expect((c.read(gameProvider).state!['tutorial'] as Map)['step'], 1);
    await settleSave(tester);
  });

  /// **THE SCRIPT OWNS THE SCREEN UNTIL IT IS OVER.**
  ///
  /// A card step used to draw nothing behind its dialog and lean on the
  /// dialog's own barrier — which is a barrier only while the dialog is up. A
  /// tap outside dropped the card and left the app fully live, with the HUD,
  /// the tabs and Add Player all reachable and nothing scheduled to put the
  /// card back. Reported from the couch twice over: the HUD icons were
  /// pressable, and clicking off the tutorial should do nothing.
  testWidgets('A TAP OUTSIDE THE CARD DOES NOTHING AT ALL', (tester) async {
    await pumpHost(tester, save());
    expect(find.byKey(const ValueKey(tutorialInputSeal)), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Still his card, still sealed: the two ways past a step are its own
    // button and Skip.
    expect(find.text(withoutEmoji(t('tut.welcome.title'))), findsOneWidget);
    expect(find.byKey(const ValueKey(tutorialInputSeal)), findsOneWidget);

    await tapFooter(tester, 'tut.skip');
    await settleSave(tester);
    // And it lets go the moment the script is over.
    expect(find.byKey(const ValueKey(tutorialInputSeal)), findsNothing);
  });

  testWidgets('A STEP WAITING ON THE SAVE SAYS SO, and has no button', (
    tester,
  ) async {
    // Either a button or a condition, never both — and a card with neither
    // would read as one whose button had failed to load.
    await pumpHost(tester, save(step: stepAt('scout_1')));
    expect(find.text(withoutEmoji(t('tut.scout_1.title'))), findsOneWidget);
    expect(find.text(t('tut.complete_above')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('coach-action-tut.welcome.btn')),
      findsNothing,
    );
    await tapFooter(tester, 'tut.skip');
    await settleSave(tester);
  });

  testWidgets('THE LOAN STEP LENDS A SIDE when it is answered', (tester) async {
    final c = await pumpHost(tester, save(step: stepAt('loan_boost'), cards: 3));
    expect(find.text(withoutEmoji(t('tut.loan_boost.title'))), findsOneWidget);
    await tapAction(tester, 'tut.loan_boost.btn');

    final cells =
        (c.read(gameProvider).state!['grid'] as Map<String, dynamic>)['cells']
            as List;
    final lent = cells.where((x) => (x as Map?)?['borrowed'] == true).length;
    expect(lent, isNot(0), reason: 'nobody was lent');
    await tester.pump(loanArrivalWindow(lent));
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
  });

  testWidgets('AND WAITS FOR THEM TO LAND before saying anything else', (
    tester,
  ) async {
    // The JS holds its script until the last card has dropped in. Advancing on
    // the same frame put the next card up over eight players arriving behind it
    // — and the arrival is the point of the step.
    final c = await pumpHost(tester, save(step: stepAt('loan_boost'), cards: 3));
    await tapAction(tester, 'tut.loan_boost.btn');
    expect(
      (c.read(gameProvider).state!['tutorial'] as Map)['step'],
      stepAt('loan_boost'),
      reason: 'it holds on the loan step until the last card has landed',
    );
    expect(find.text(withoutEmoji(t('tut.play_match.title'))), findsNothing);

    final cells =
        (c.read(gameProvider).state!['grid'] as Map<String, dynamic>)['cells']
            as List;
    final lent = cells.where((x) => (x as Map?)?['borrowed'] == true).length;
    await tester.pump(loanArrivalWindow(lent));
    await tester.pumpAndSettle();
    expect(
      (c.read(gameProvider).state!['tutorial'] as Map)['step'],
      stepAt('play_match'),
      reason: 'and moves on once they have',
    );
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
  });

  /// **THE GRID EMPTIES FIRST AND THE CARD FOLLOWS**, which is the JS's
  /// `loan_depart.onEnterAsync` and was the reported break: Colin announced the
  /// loan had gone home over a grid still full of them, and they vanished a tap
  /// later on whatever screen the player was on by then.
  testWidgets('AND THE DEPARTURE TAKES THEM BACK AND PAYS', (tester) async {
    final state = save(step: stepAt('loan_boost'), cards: 3);
    lendTutorialPlayers(state);
    (state['tutorial'] as Map<String, dynamic>)['step'] = stepAt(
      'loan_depart',
    );
    final c = await pumpHost(tester, state, settle: false);
    final before =
        ((c.read(gameProvider).state!['resources'] as Map)['fanCoins'] as num)
            .toInt();
    final leaving = c.read(loanCardIdsProvider).length;
    expect(leaving, greaterThan(0));

    // Past the hold — the tab, the cards arriving, a beat to see them — and
    // one card into the flight.
    await tester.pump();
    await tester.pump(loanDepartHold(leaving));
    await tester.pump(loanDepartureDuration);

    // Mid-flight: nothing said yet, nothing taken yet, and nothing pressable.
    expect(find.text(withoutEmoji(t('tut.loan_depart.title'))), findsNothing);
    expect(
      (c.read(gameProvider).state!['grid'] as Map)['cells'],
      contains(predicate((c) => (c as Map?)?['borrowed'] == true)),
    );
    expect(c.read(loanDepartingProvider), isTrue);
    expect(find.byKey(const ValueKey(tutorialInputSeal)), findsOneWidget);

    await tester.pump(loanDepartHold(leaving) + loanDepartureWindow(leaving));
    await tester.pumpAndSettle();

    // Only now does he say it, and the grid he says it over is empty.
    final after = c.read(gameProvider).state!;
    final cells = (after['grid'] as Map<String, dynamic>)['cells'] as List;
    expect(cells.where((x) => (x as Map?)?['borrowed'] == true), isEmpty);
    expect(c.read(loanDepartingProvider), isFalse);
    // **The seal stays** — it is held for the whole script now, not just for
    // the flight: a step between cards, or a card a stray tap dropped, used to
    // leave the HUD, the tabs and Add Player all live. What ended here is the
    // FLIGHT, which is the line above and the card below.
    expect(find.byKey(const ValueKey(tutorialInputSeal)), findsOneWidget);
    expect(find.text(withoutEmoji(t('tut.loan_depart.title'))), findsOneWidget);
    expect(
      ((after['resources'] as Map)['fanCoins'] as num).toInt() - before,
      tutorialFarewellCoins,
    );

    await tapAction(tester, 'tut.loan_depart.btn');
    // **And that is the script.** The farewell IS the last card — the tenth,
    // which told the player to open the tab they were already standing on,
    // went with it.
    final tutorial = c.read(gameProvider).state!['tutorial'] as Map;
    expect(tutorial['step'], tutorialSteps.length);
    expect(tutorial['done'], isTrue);
    expect(tutorial['completed'], isTrue, reason: 'Colin\'s tour starts here');
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
  });

  testWidgets('SKIP ENDS IT AT ANY STEP, and takes the loan back', (
    tester,
  ) async {
    // **THE SPEC IS EXPLICIT, and this asserted the reverse.** It said a skip
    // leaves the side lent; `Tutorial.js`'s teardown runs on both routes and
    // says "Always remove any loan cards — covers both skip and normal
    // completion. Coins are NOT awarded here." `skipTutorial` does exactly
    // that, so the engine was right and the assertion had been red against it.
    // Its twin in `tutorial_engine_test.dart` was wrong the same way.
    // Lent, and then parked on the step AFTER the arrival — the loan step
    // seals input while the cards are still flying in, so a skip tapped there
    // is a skip tapped through `tutorialInputSeal`. `play_match` is the first
    // step with a side on the grid and nothing in the air.
    final state = save(step: stepAt('loan_boost'), cards: 3);
    lendTutorialPlayers(state);
    (state['tutorial'] as Map<String, dynamic>)['step'] = stepAt('play_match');
    final c = await pumpHost(tester, state);
    final leaving = c.read(loanCardIdsProvider).length;
    await tapFooter(tester, 'tut.skip');
    // **`_skip` AWAITS THE FLIGHT.** It runs `departLoan` — the same shatter
    // the auto-sell uses — and only then marks the script done, so a test that
    // taps and reads on the next frame reads a tutorial that is still running.
    await tester.pump(loanDepartureWindow(leaving));
    await tester.pumpAndSettle();

    final after = c.read(gameProvider).state!;
    expect((after['tutorial'] as Map)['done'], isTrue);
    final cells = (after['grid'] as Map<String, dynamic>)['cells'] as List;
    expect(
      cells.where((x) => (x as Map?)?['borrowed'] == true),
      isEmpty,
      reason: 'the loan goes back on a skip too',
    );
    expect(find.text(withoutEmoji(t('tut.play_match.title'))), findsNothing);
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 1));
  });

  testWidgets('A FINISHED SAVE SHOWS NOTHING AT ALL', (tester) async {
    final state = save();
    (state['tutorial'] as Map<String, dynamic>)['done'] = true;
    await pumpHost(tester, state);
    expect(find.text(withoutEmoji(t('tut.welcome.title'))), findsNothing);
  });

  testWidgets('the reaction step reads the RESULT, not the first-match line', (
    tester,
  ) async {
    final state = save(step: stepAt('match_result_reaction'));
    (state['progression'] as Map<String, dynamic>)['lastMatchResult'] =
        <String, dynamic>{'won': true, 'score': '2-0'};
    await pumpHost(tester, state);
    expect(find.text(withoutEmoji(t('tut.match_reaction.win_title'))), findsOneWidget);
    expect(find.textContaining('2-0'), findsOneWidget);
    await tapFooter(tester, 'tut.skip');
    await settleSave(tester);
  });

  testWidgets('and it is in the player\'s language', (tester) async {
    setLocale('de');
    await pumpHost(tester, save());
    expect(find.textContaining('tut.'), findsNothing);
    await tapFooter(tester, 'tut.skip');
    await settleSave(tester);
  });

  testWidgets('NOTHING OPENS WHILE THE MATCH OWNS THE SCREEN', (tester) async {
    // `seasonAwardedPlayed` moves the instant the result settles — while the
    // player is still watching full time — so the reaction card went up over
    // the match screen, before the summary and before the money. The tutorial's
    // own popup block does not cover it, because a coach card is a `showDialog`
    // rather than a queued popup. Reported as being stuck on the game screen.
    blockPopups(matchPopupBlocker);
    addTearDown(() => unblockPopups(matchPopupBlocker));

    await pumpHost(tester, save(step: stepAt('match_result_reaction')));
    expect(
      find.byKey(const ValueKey('coach-card')),
      findsNothing,
      reason: 'the reaction card opened over the match',
    );

    // And it arrives the moment the match lets go.
    unblockPopups(matchPopupBlocker);
    emit('match:close');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach-card')), findsOneWidget);
    await tapFooter(tester, 'tut.skip');
    await settleSave(tester);
  });
}
