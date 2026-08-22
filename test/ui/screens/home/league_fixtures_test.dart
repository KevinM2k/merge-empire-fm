/// The fixtures sheet.
///
/// **`fixtures.opp_rating` and `fixtures.opp_rating_est` had no caller.** The
/// opponent's rating is drawn as a bare number in an unlabelled 34px column,
/// between a club name and a score — and the sentence identifying it, including
/// the one that explains what the tilde means, has shipped in ten languages
/// since the generator first ran.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/league_sheets.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<void> pumpFixtures(
  WidgetTester tester, {
  bool dropOpponentRatings = false,
}) async {
  tester.view.physicalSize = const Size(420 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Through the RUNNER: the season's schedule is one of the sweeps a boot owes,
  // and `game.load()` alone leaves the sheet with nothing to draw.
  final save = container.read(gameRunnerProvider).boot();
  if (dropOpponentRatings) {
    (save['progression'] as Map<String, dynamic>).remove('seasonOpponentRatings');
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: FixturesView()),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Every fixture row's rating number, paired with the sentence it carries.
List<({String shown, String tip})> ratings(WidgetTester tester) => [
  for (final tip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    if (tip.child case final Text text
        when '${text.key}'.contains('fixture-rating-'))
      (shown: text.data ?? '', tip: tip.message ?? ''),
];

void main() {
  tearDown(resetLocale);

  testWidgets('THE OPPONENT RATING SAYS WHAT IT IS', (tester) async {
    await pumpFixtures(tester);
    final rows = ratings(tester);
    expect(rows, isNotEmpty, reason: 'no fixture row drew a rating at all');
    for (final row in rows) {
      final n = int.parse(row.shown.replaceAll('~', ''));
      final estimated = row.shown.startsWith('~');
      expect(
        row.tip,
        t(
          estimated ? 'fixtures.opp_rating_est' : 'fixtures.opp_rating',
          {'rating': n},
        ),
      );
      // The placeholder is filled, not printed.
      expect(row.tip, isNot(contains('{rating}')));
      expect(row.tip, contains('$n'));
    }
  });

  testWidgets('AND AN ESTIMATE SAYS SO IN WORDS, not only with a tilde', (
    tester,
  ) async {
    // The tilde was the whole signal, which is a convention the player has to
    // already know — and `fixtures.opp_rating_est` spells it out ("estimated
    // ~division midpoint") in ten languages with nothing able to reach it.
    //
    // **A booted save has no estimated rows**, and finding that out is half the
    // value of writing this: `seasonOpponentRatings` is materialised for the
    // whole season by the boot sweep, so `ratingEstimated` is only true on a
    // save whose ratings have not been drawn. That is the state to build, not
    // one to hope a fresh save happens to be in.
    await pumpFixtures(tester, dropOpponentRatings: true);
    final rows = ratings(tester);
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.shown.startsWith('~')), isTrue);
    for (final row in rows) {
      final n = int.parse(row.shown.replaceAll('~', ''));
      expect(row.tip, t('fixtures.opp_rating_est', {'rating': n}));
      expect(row.tip, isNot(t('fixtures.opp_rating', {'rating': n})));
    }
  });

  testWidgets('and it is in the player\'s language', (tester) async {
    setLocale('de');
    await pumpFixtures(tester);
    final rows = ratings(tester);
    expect(rows, isNotEmpty);
    expect(
      rows.every((r) => !r.tip.contains('Estimated opponent rating')),
      isTrue,
    );
    expect(rows.first.tip, isNotEmpty);
  });
}
