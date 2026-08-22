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
  testWidgets('HIS NAME IS NOT IN HIS OWN SENTENCE', (tester) async {
    // The header read `COACH COLIN SUGGESTS COUNTER ATTACK` — him talking
    // about himself in the third person, on a bubble with his face on it,
    // coming out of his own orb, on a card the player opened by tapping him.
    //
    // **No new copy was needed, which is the point**: making him say "I
    // suggest" means a new `t()` key in ten catalogues generated from a repo
    // this one does not own; taking the name out needs nothing. When there is
    // no suggestion to make, the label stays — the line has to say who is
    // speaking somehow.
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
    if (suggested != null) {
      expect(find.text(t('coach.label').toUpperCase()), findsNothing);
      expect(
        find.text(t('coach.suggestion_label').toUpperCase()),
        findsOneWidget,
      );
    } else {
      expect(find.text(t('coach.label').toUpperCase()), findsOneWidget);
    }
  });

}
