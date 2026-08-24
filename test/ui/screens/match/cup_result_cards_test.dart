/// What a cup tie says when it is over.
///
/// **Twenty-odd `cup.round_win.*`, `cup.knocked_out.*` and `cup.banner.*`
/// strings shipped in ten languages with no caller** — the whole of the cup's
/// reaction. A round won and a run ended were the same event from the screen's
/// side: a scoreline, a toast, and back to the Play tab.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_result_cards.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

Future<void> pumpCard(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => open(context),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('which line a win earns', () {
    test('IT READS THE ROUND AHEAD, not the one just won', () {
      // "One win away from lifting the cup" is a thing to say to somebody about
      // to play a final, not to somebody who has just won a quarter-final —
      // and the difference is one index.
      expect(
        cupRoundWinBodyKey(nextIsFinal: true, nextIsSemi: false),
        'cup.round_win.final_next',
      );
      expect(
        cupRoundWinBodyKey(nextIsFinal: false, nextIsSemi: true),
        'cup.round_win.semi_next',
      );
      expect(
        cupRoundWinBodyKey(nextIsFinal: false, nextIsSemi: false),
        'cup.round_win.generic_next',
      );
    });
  });

  group('which line an exit earns', () {
    test('LOSING A FINAL IS NOT LOSING A QUARTER-FINAL', () {
      // "So close to glory" is the only thing worth saying to somebody who lost
      // there, and the generic line would read as dismissive.
      expect(
        cupKnockedOutBodyKey(wasFinal: true, wasSemi: false),
        'cup.knocked_out.body_final',
      );
      expect(
        cupKnockedOutBodyKey(wasFinal: false, wasSemi: true),
        'cup.knocked_out.body_semi',
      );
      expect(
        cupKnockedOutBodyKey(wasFinal: false, wasSemi: false),
        'cup.knocked_out.body',
      );
    });

    test('IT IS TOLD BY POSITION, NOT BY THE NAME — "Quarter-Final" contains '
        '"final"', () {
      // Sniffing the string called a quarter-final exit a heartbreak at the
      // last hurdle. The round index cannot be wrong about this, which is why
      // the caller works it out from `cup.rounds.length`.
      const rounds = ['Quarter-Final', 'Semi-Final', 'Final'];
      String forRound(int i) => cupKnockedOutBodyKey(
        wasFinal: i == rounds.length - 1,
        wasSemi: i == rounds.length - 2,
      );
      expect(forRound(0), 'cup.knocked_out.body');
      expect(forRound(1), 'cup.knocked_out.body_semi');
      expect(forRound(2), 'cup.knocked_out.body_final');
    });
  });

  testWidgets('a round won says what is next', (tester) async {
    await pumpCard(
      tester,
      (context) => showCupRoundWin(
        context,
        nextRoundName: 'Semi-Final',
        nextIsFinal: false,
        nextIsSemi: true,
        nextOpponent: 'Ayton',
      ),
    );
    expect(find.text(t('cup.round_win.title')), findsOneWidget);
    expect(
      find.text(t('cup.round_win.through', {'round': 'Semi-Final'})),
      findsOneWidget,
    );
    expect(
      find.text(t('cup.round_win.next_up', {'opponent': 'Ayton'})),
      findsOneWidget,
    );
  });

  testWidgets('and with no opponent drawn it says what the round means', (
    tester,
  ) async {
    await pumpCard(
      tester,
      (context) => showCupRoundWin(
        context,
        nextRoundName: 'Final',
        nextIsFinal: true,
        nextIsSemi: false,
      ),
    );
    expect(find.text(t('cup.round_win.final_next')), findsOneWidget);
  });

  testWidgets('AN ELIMINATION IS NOT A CELEBRATION', (tester) async {
    // The splash is a celebration by default; the same card in green would read
    // as congratulating somebody on going out.
    await pumpCard(
      tester,
      (context) => showCupKnockedOut(
        context,
        cupName: 'Regional Cup',
        roundName: 'Final',
        wasFinal: true,
        wasSemi: false,
      ),
    );
    expect(find.text(t('cup.knocked_out.title')), findsOneWidget);
    expect(
      find.text(t('cup.knocked_out.round', {'round': 'Final'})),
      findsOneWidget,
    );
    expect(find.text(t('cup.knocked_out.body_final')), findsOneWidget);
    expect(find.text('💔'), findsOneWidget);
  });

  testWidgets('the trophy is its own card, not a round-win for round four', (
    tester,
  ) async {
    await pumpCard(
      tester,
      (context) => showCupWon(context, cupName: 'Regional Cup'),
    );
    expect(find.text(t('cup.banner.champions')), findsOneWidget);
    expect(
      find.text(t('cup.banner.you_won', {'cup': 'Regional Cup'})),
      findsOneWidget,
    );
  });
}
