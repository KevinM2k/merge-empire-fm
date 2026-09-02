/// His read on OUR squad, all the way to the pool the bubble reads.
///
/// **The engine being right proves nothing about a player ever seeing it**, and
/// these thirteen keys are the case in point: they were translated into ten
/// languages and no file in `lib/` mentioned the prefix at all. So this asks
/// the provider the bubble actually reads, on a save booted the way the app
/// boots one.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/coach_bubble.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/theme/tactic_style.dart' show tacticColor;
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart'
    show strategyIdProvider;

ProviderContainer boot() {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Through the runner: the season's schedule is a boot sweep, and the coach
  // has nothing to compare against without one.
  container.read(gameRunnerProvider).boot();
  return container;
}

void main() {
  tearDown(resetLocale);

  test('A FRESH SAVE GETS A SQUAD-STATE LINE, and it is the empty squad', () {
    // Nobody on the books and the coin to fix it, which is the one branch
    // that asks whether the advice is actionable before giving it.
    final tips = boot().read(coachTipsProvider);
    final ids = tips.map((t) => t.id).toList();
    expect(ids, contains('squad_state'));
    expect(
      tips.firstWhere((t) => t.id == 'squad_state').text,
      isIn(t('squadstate.few_players').split('|')),
    );
  });

  test('it is the LAST thing in the pool', () {
    // Everything above it is about the fixture in front of us; a squad note is
    // what he falls back on when there is not enough to say about the
    // opponent.
    final ids = boot().read(coachTipsProvider).map((t) => t.id).toList();
    expect(ids.last, 'squad_state');
  });

  test('IT IS ONE SENTENCE, not the whole pool, and it HOLDS STILL', () {
    final c = boot();
    String line() => c
        .read(coachTipsProvider)
        .firstWhere((t) => t.id == 'squad_state')
        .text;
    final first = line();
    expect(first, isNot(contains('|')));
    expect(first, isNot(contains('{')));
    expect(first.trim(), isNotEmpty);
    for (var i = 0; i < 5; i++) {
      expect(line(), first, reason: 'Colin rephrased himself on read ${i + 2}');
    }
  });

  test('and it displaces the generic fallback rather than joining it', () {
    // `manager.default_tip` is the port's own filler and only exists for a pool
    // with nothing in it. A squad state IS something, so the filler goes.
    final ids = boot().read(coachTipsProvider).map((t) => t.id).toList();
    expect(ids, isNot(contains('default')));
  });

  test('and the line is in the player\'s language', () {
    setLocale('de');
    final text = boot()
        .read(coachTipsProvider)
        .firstWhere((t) => t.id == 'squad_state')
        .text;
    expect(text, isNot(contains('squadstate.')));
    expect(text, isNot(contains('on the books')));
  });
  testWidgets('HIS HEADER READS THE SAME EVERY TIME', (tester) async {
    // **This reverses a decision, and both halves are worth keeping.**
    //
    // The name came OFF whenever there was a tactic to suggest, because `COACH
    // COLIN SUGGESTS COUNTER ATTACK` is him talking about himself in the third
    // person — on a bubble with his face on it, coming out of his own orb, on a
    // card the player opened by tapping him.
    //
    // What that produced is a header that changes shape depending on whether he
    // has advice: COACH COLIN every other time, SUGGESTS on the one that
    // matters. Reported from the couch — it should always read the same. A
    // redundant name is a smaller cost than an unpredictable title.
    //
    // **No new copy either way**, which was the point of the earlier note too:
    // both keys are shipped, and this is the two of them in a row.
    final c = boot();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(body: CoachLabelProbe()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final suggested = c.read(coachSuggestedTacticProvider);
    // His name, always — with or without something to suggest.
    expect(find.text(t('coach.label').toUpperCase()), findsOneWidget);
    expect(
      find.text(t('coach.suggestion_label').toUpperCase()),
      suggested == null ? findsNothing : findsOneWidget,
    );

    // **AND THE TACTIC IS PRINTED IN ITS OWN COLOUR** — purple for a counter,
    // blue for a defensive block, and so on. It always was; this pins it,
    // because it was queried from the couch and a fallback to the kit accent is
    // exactly what a missing table row would look like.
    if (suggested != null) {
      final label = find.text(t('strategy.$suggested.name').toUpperCase());
      expect(label, findsOneWidget);
      expect(
        tester.widget<Text>(label).style!.color,
        tacticColor(tester.element(label), suggested),
      );
    }
  });

  testWidgets('AND HE SAYS SO EVEN WHEN THE TACTIC IS ALREADY SET', (
    tester,
  ) async {
    // `coachSuggestedTacticProvider` is "his pick, and it is not what you have"
    // — the right question for the match screen, where a suggestion is an offer
    // to CHANGE something, and the wrong one for his header. A manager already
    // playing the right way should see him agree rather than fall silent.
    // Reported from the couch.
    final c = boot();
    final pick = c.read(coachTacticPickProvider);
    expect(pick, isNotNull, reason: 'he has no read at all on a fresh save');
    c.read(gameProvider).update(
      (s) => (s['squad'] as Map<String, dynamic>)['strategyId'] = pick,
    );
    expect(
      c.read(coachSuggestedTacticProvider),
      isNull,
      reason: 'there is nothing left to offer a switch to',
    );
    expect(c.read(coachTacticPickProvider), pick);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(body: CoachLabelProbe()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t('coach.label').toUpperCase()), findsOneWidget);
    expect(
      find.text(t('coach.suggestion_label').toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(t('strategy.$pick.name').toUpperCase()), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });


  testWidgets('AND TAPPING THE TACTIC SETS IT', (tester) async {
    // He names the one he would pick and the player then had to go and find it
    // in a dropdown on another card — two steps to agree with advice already on
    // screen. Asked for from the couch. `setStrategy` is the picker's own
    // writer, so the dropdown, the multipliers and the arrow all follow from
    // the same key without being told.
    final c = boot();
    final pick = c.read(coachTacticPickProvider);
    expect(pick, isNotNull);
    expect(c.read(strategyIdProvider), isNot(pick));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(body: CoachLabelProbe()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('coach-take-$pick')));
    await tester.pumpAndSettle();
    expect(c.read(strategyIdProvider), pick);
    // And he keeps agreeing with you rather than falling silent — the header is
    // his READ, not his disagreements.
    expect(c.read(coachTacticPickProvider), pick);
    expect(find.text(t('strategy.$pick.name').toUpperCase()), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
