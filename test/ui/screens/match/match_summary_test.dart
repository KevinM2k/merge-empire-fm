/// Full time, on a screen of its own.
///
/// The result, the coins and the three quest outcomes used to be appended under
/// a ninety-minute commentary feed. And the doubling offer — which
/// `match_launcher` has deferred `applyMatchRewards` for since it was written —
/// had nowhere to live at all.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/match/match_summary.dart';
import 'package:merge_empire_fc/ui/screens/match/summary_league_move.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// An ad server that answers however the test needs it to.
class FakeAds implements RewardedAds {
  FakeAds(this.outcome);

  final AdOutcome outcome;
  int shown = 0;
  int prepared = 0;

  @override
  Future<AdOutcome> show(String placement) async {
    shown++;
    return outcome;
  }

  @override
  void prepare(String placement) => prepared++;
}

Map<String, dynamic> result({
  bool won = true,
  bool drawn = false,
  int coins = 300,
  int trophies = 0,
  List<Map<String, dynamic>> events = const [],
  List<Map<String, dynamic>>? questResults,
}) => {
  'clubName': 'Testville',
  'opponentName': 'Ayton',
  'isHome': true,
  'won': won,
  'drawn': drawn,
  'ourGoals': won ? 2 : 0,
  'theirGoals': won ? 0 : 1,
  'coinsEarned': coins,
  'trophiesEarned': trophies,
  'events': events,
  'questResults': ?questResults,
};

Future<MatchSummaryScreenState> pumpSummary(
  WidgetTester tester,
  Map<String, dynamic> res, {
  RewardedAds? ads,

  /// Through the runner rather than a bare load — the schedule and the
  /// opponents are boot sweeps, and a save with no fixtures has no table for
  /// the standings block to move.
  bool boot = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
      ),
      if (ads != null) rewardedAdsProvider.overrideWithValue(ads),
    ],
  );
  addTearDown(container.dispose);
  if (boot) {
    container.read(gameRunnerProvider).boot();
  } else {
    container.read(gameProvider).load();
  }

  // **PUSHED, not the home route.** The screen pops itself when the offer is
  // answered, and a route with nothing under it cannot be popped — which is a
  // property of the test harness rather than of the screen.
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          navigatorKey: nav,
          // Reduced motion: the manager's shot runs FOREVER, so a live one makes
          // `pumpAndSettle` never return. The screen is not about him moving.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pump();
  unawaited(
    nav.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => MatchSummaryScreen(result: res)),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<MatchSummaryScreenState>(find.byType(MatchSummaryScreen));
}

void main() {
  tearDown(resetLocale);

  testWidgets('it says what happened, in one screen', (tester) async {
    await pumpSummary(
      tester,
      result(
        events: [
          {
            'minute': 22,
            'type': 'goal',
            'team': 'home',
            'scorer': 'Bobby',
            'scorerInstanceId': 'gone',
          },
        ],
      ),
    );
    expect(find.byKey(const ValueKey('match-summary')), findsOneWidget);
    expect(find.text(t('match.victory').toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('summary-score')), findsOneWidget);
    expect(find.text('2–0'), findsOneWidget);
    // Who scored, even for a man the save has never heard of: the name is on
    // the event whether or not there is a card to draw.
    expect(find.text('Bobby'), findsOneWidget);
  });

  testWidgets('and a defeat says so rather than dressing it up', (
    tester,
  ) async {
    await pumpSummary(tester, result(won: false));
    expect(find.text(t('match.defeat').toUpperCase()), findsOneWidget);
  });

  testWidgets('THE VERDICT IS THE RESULT\'S COLOUR, not the club\'s', (
    tester,
  ) async {
    // It wore `accentBright`, which belongs to the KIT: a side in red was told
    // it had won in the same red this game uses for a goal against, and a
    // green-shirted defeat read as a win.
    for (final (won, drawn) in [(true, false), (false, true), (false, false)]) {
      await pumpSummary(tester, result(won: won, drawn: drawn));
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('summary-verdict')),
      );
      expect(
        text.style?.color,
        verdictInk(won: won, drawn: drawn),
        reason: 'won: $won, drawn: $drawn',
      );
    }
  });

  testWidgets('IT IS ONE BOX, not four notes on the sky', (tester) async {
    // The verdict, the money and the quest outcomes each sat loose on the
    // gradient with only the scoreline in a panel — four halves of the same
    // statement, reading as four unrelated notes.
    await pumpSummary(
      tester,
      result(
        questResults: [
          {
            'id': 'match_clean_sheet',
            'icon': '🧱',
            'target': 1,
            'passed': true,
            'coins': 120,
          },
        ],
      ),
    );
    final card = find.ancestor(
      of: find.byKey(const ValueKey('summary-verdict')),
      matching: find.byType(GlassPanel),
    );
    expect(card, findsOneWidget);
    for (final part in [
      const ValueKey('summary-score'),
      const ValueKey('summary-payout'),
      const ValueKey('match-quests'),
    ]) {
      expect(
        find.descendant(of: card, matching: find.byKey(part)),
        findsOneWidget,
        reason: '$part is not in the box the score is in',
      );
    }
  });

  testWidgets('THE TABLE MOVES ON IT', (tester) async {
    // A league match is only half told by its own scoreline: the other half is
    // where it left you.
    await pumpSummary(tester, result(), boot: true);
    expect(find.byKey(const ValueKey('summary-table')), findsOneWidget);
    await tester.pump(leagueMoveHold);
    await tester.pumpAndSettle();
  });

  testWidgets('and a CUP TIE has no table to move', (tester) async {
    // A cup round is not a league fixture; it changes no standing.
    await pumpSummary(tester, result()..['isCup'] = true, boot: true);
    expect(find.byKey(const ValueKey('summary-table')), findsNothing);
  });

  group('the doubling offer', () {
    testWidgets('THE VIDEO DOUBLES WHAT THE MATCH PAID', (tester) async {
      // `applyMatchRewards` is deferred until this screen closes precisely so
      // the offer can change the figure before it is credited.
      final ads = FakeAds(AdOutcome.rewarded);
      final res = result(coins: 300);
      await pumpSummary(tester, res, ads: ads);
      expect(ads.prepared, 1, reason: 'the offer was not warmed up');

      await tester.tap(find.byKey(const ValueKey('summary-double')));
      await tester.pumpAndSettle();
      expect(ads.shown, 1);
      expect(res['coinsEarned'], 600);
    });

    testWidgets('and every other answer keeps the single reward', (
      tester,
    ) async {
      for (final outcome in [AdOutcome.dismissed, AdOutcome.unavailable]) {
        final ads = FakeAds(outcome);
        final res = result(coins: 300);
        await pumpSummary(tester, res, ads: ads);
        await tester.tap(find.byKey(const ValueKey('summary-double')));
        await tester.pumpAndSettle();
        expect(res['coinsEarned'], 300, reason: '$outcome paid double');
      }
    });

    testWidgets('No Thanks is a text link, not a second offer', (tester) async {
      // Two buttons stacked read as a choice between two offers, and a muted one
      // still invites a press. This is the decline.
      final ads = FakeAds(AdOutcome.rewarded);
      final res = result(coins: 300);
      await pumpSummary(tester, res, ads: ads);
      expect(find.byKey(const ValueKey('summary-no-thanks')), findsOneWidget);
      expect(find.byType(TextButton), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('summary-no-thanks')));
      await tester.pumpAndSettle();
      expect(ads.shown, 0, reason: 'declining showed a video');
      expect(res['coinsEarned'], 300);
    });

    testWidgets('a match that paid nothing makes no offer at all', (
      tester,
    ) async {
      final ads = FakeAds(AdOutcome.rewarded);
      await pumpSummary(tester, result(coins: 0), ads: ads);
      expect(find.byKey(const ValueKey('summary-double')), findsNothing);
      expect(find.byKey(const ValueKey('summary-continue')), findsOneWidget);
      expect(ads.prepared, 0, reason: 'warmed a video for no offer');
    });
  });

  group('the quest outcomes', () {
    List<Map<String, dynamic>> outcomes() => [
      {
        'id': 'match_clean_sheet',
        'icon': '🧱',
        'target': 1,
        'passed': true,
        'coins': 120,
      },
      {
        'id': 'match_win_margin',
        'icon': '💪',
        'target': 2,
        'passed': false,
        'coins': 0,
      },
    ];

    testWidgets('list what was won AND what was missed', (tester) async {
      // The misses are the point of showing all three: they are what makes the
      // next set worth reading.
      await pumpSummary(tester, result(questResults: outcomes()));
      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-quest-match_clean_sheet')),
        findsOneWidget,
      );
      expect(find.text(t('quests.missed')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-quests-total')),
        findsOneWidget,
        reason: 'one of them paid',
      );
    });

    testWidgets('and a match with no track shows nothing at all', (
      tester,
    ) async {
      await pumpSummary(tester, result());
      expect(find.byKey(const ValueKey('match-quests')), findsNothing);
    });

    testWidgets('AND THE MONEY THEY PAID IS IN WHAT THE SCREEN CLAIMS', (
      tester,
    ) async {
      // A match quest auto-pays at the whistle, so it never passes through the
      // offer or through `applyMatchRewards` — and the screen was quoting the
      // fee alone. The player walked away with 420 while being told 300, on
      // the one line whose job is to say what declining is worth.
      await pumpSummary(
        tester,
        result(coins: 300, questResults: outcomes()),
        ads: FakeAds(AdOutcome.rewarded),
      );
      expect(
        find.text('${t('match.no_thanks')} — ${formatCoins(420)}'),
        findsOneWidget,
        reason: 'declining understated what the player keeps',
      );
      // And both answers are totals, so the difference between them is
      // exactly what the video is worth.
      expect(
        find.text('${t('match.double_reward')} → ${formatCoins(720)}'),
        findsOneWidget,
      );
      expect(find.text('+${formatCoins(420)}'), findsOneWidget);
    });

    testWidgets('a match that paid no fee still shows the quest money', (
      tester,
    ) async {
      // No offer to make and money to report: the two are independent, and a
      // teaser under a figure nothing can double is a button that is not there.
      await pumpSummary(tester, result(coins: 0, questResults: outcomes()));
      expect(find.byKey(const ValueKey('summary-payout')), findsOneWidget);
      expect(find.text('+${formatCoins(120)}'), findsOneWidget);
      expect(find.text(t('match.double_teaser')), findsNothing);
      expect(find.byKey(const ValueKey('summary-double')), findsNothing);
    });

    testWidgets('a track where nothing came off has no total', (tester) async {
      await pumpSummary(
        tester,
        result(
          questResults: [
            {
              'id': 'match_clean_sheet',
              'icon': '🧱',
              'target': 1,
              'passed': false,
              'coins': 0,
            },
          ],
        ),
      );
      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-quests-total')), findsNothing);
    });
  });
}
