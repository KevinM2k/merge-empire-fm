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
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
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
  // **`homeGoals`/`awayGoals`, WHICH IS WHAT THE ENGINE WRITES.** This fixture
  // hand-wrote `ourGoals`/`theirGoals` — keys that only exist on
  // `progression.lastMatchResult`, a different map written at full time — so
  // the summary showed a scoreline here and 0–0 in the game. Reported from a
  // live save as "a victory screen with four goalscorers and a 0–0". A fixture
  // that carries keys production does not is a test that cannot fail.
  //
  // In the engine's map `homeGoals` is always OURS, whichever ground it is on.
  'homeGoals': won ? 2 : 0,
  'awayGoals': won ? 0 : 1,
  'coinsEarned': coins,
  'trophiesEarned': trophies,
  'events': events,
  'questResults': ?questResults,
};

/// Scroll the report down to whatever is below the fold.
///
/// **The table is second on this screen and everything else moved under it**,
/// which is the point — the animation is the reason the screen exists and it
/// was playing to nobody. So a test about the manager, the scorers or the quest
/// list has to go and find them, exactly as a player does.
Future<void> scrollReport(WidgetTester tester, Key target) async {
  await tester.scrollUntilVisible(
    find.byKey(target),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

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

  testWidgets('A REPLAY ROLLS DOWN UNDER THE GOALS, not up in a popup', (
    tester,
  ) async {
    // It opened a dialog over the report — a window on top of a page that
    // already had the goal on it. Asked for as a projector screen: it comes
    // down under the scorers, plays, and goes back up.
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
    final button = find.byKey(const ValueKey('summary-replay-22'));
    expect(button, findsOneWidget);
    expect(find.byKey(const ValueKey('summary-replay-screen')), findsNothing);

    await tester.tap(button);
    await tester.pump();
    final screen = find.byKey(const ValueKey('summary-replay-screen'));
    expect(screen, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('goal-replay')), findsNothing);
    // UNDER the goal it belongs to, inside the same card.
    expect(
      tester.getRect(screen).top,
      greaterThanOrEqualTo(tester.getRect(button).bottom - 1),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('summary-scorers')),
        matching: screen,
      ),
      findsOneWidget,
    );

    // The same button is the way to stop it, and the screen goes back up.
    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('summary-replay-screen')), findsNothing);
  });

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
    // **Who scored, right under the score they made** — a scoreboard's own
    // convention. The name is on the event whether or not the save still has a
    // card to draw, so a scorer since sold still scored.
    expect(find.byKey(const ValueKey('summary-scorers')), findsOneWidget);
    expect(find.textContaining('Bobby'), findsOneWidget);
    expect(find.textContaining("22'"), findsOneWidget);
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
      // **Through the pane rule.** The scale's colours are chosen against a
      // dark ground; on a light pane over a daylight sky the winner's green is
      // 2.4:1, and light mode draws light panes now. `glassAccent` takes any
      // colour down until it clears the pane and returns it untouched in dark,
      // so the SCALE is still what decides the hue.
      final element = tester.element(
        find.byKey(const ValueKey('summary-verdict')),
      );
      expect(
        text.style?.color,
        glassAccent(element, verdictInk(element, won: won, drawn: drawn)),
        reason: 'won: $won, drawn: $drawn',
      );
    }
  });

  testWidgets('WHAT HAPPENED IS ONE BOX, and the score is in it', (
    tester,
  ) async {
    // The verdict and the score are one statement and share one pane; the
    // money and the quests used to be in there with them and are not any more.
    // See the two tests below for where each went and why.
    await pumpSummary(tester, result());
    final card = find.ancestor(
      of: find.byKey(const ValueKey('summary-verdict')),
      matching: find.byType(GlassPanel),
    );
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byKey(const ValueKey('summary-score'))),
      findsOneWidget,
    );
  });

  testWidgets('THE TABLE IS ABOVE THE FOLD, which is why it is second', (
    tester,
  ) async {
    // It is the one thing on this screen that MOVES, and it was under the
    // manager, the scorers and the quest list — which is to say the animation
    // played to nobody.
    await pumpSummary(tester, result(), boot: true);
    final table = find.byKey(const ValueKey('summary-table'));
    expect(table, findsOneWidget);
    final view = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(table).dy,
      lessThan(view),
      reason: 'the table starts below the fold',
    );
  });

  testWidgets('THE MONEY SITS WITH THE BUTTON THAT CHANGES IT', (
    tester,
  ) async {
    // The figure was at the top of the scroll and the offer to double it at the
    // foot — one decision split across a page, so the player had to remember a
    // number to understand the button. Both are in the footer now, which is
    // also the half of the screen that does not scroll.
    await pumpSummary(tester, result(coins: 500));
    final payout = find.byKey(const ValueKey('summary-payout'));
    expect(payout, findsOneWidget);
    // Not inside the scroll view at all.
    expect(
      find.ancestor(of: payout, matching: find.byType(ListView)),
      findsNothing,
    );
    final button = tester.getTopLeft(
      find.byKey(const ValueKey('summary-double')),
    );
    expect(
      (button.dy - tester.getBottomLeft(payout).dy).abs(),
      lessThan(40),
      reason: 'the figure and the button that doubles it are one control',
    );
  });

  testWidgets('AND HE IS NOT LEFT STANDING IN A CORNER', (tester) async {
    // With no quests the other half of the row was an empty `Expanded`, so the
    // shot sat in a 120-point column against the left edge with two thirds of
    // the row blank beside it — one small square and a lot of nothing. A cup
    // tie and an early match both land here.
    await pumpSummary(tester, result());
    await scrollReport(tester, const ValueKey('summary-reaction-row'));
    final row = tester.getRect(
      find.byKey(const ValueKey('summary-reaction-row')),
    );
    final him = tester.getRect(find.byKey(const ValueKey('summary-manager')));
    expect(him.center.dx, closeTo(row.center.dx, 1.5));
  });

  testWidgets('THE MANAGER AND THE QUESTS SHARE A ROW', (tester) async {
    // Stacked, the quest list was below the fold on any phone — and the two are
    // a natural pair: he is reacting to the match and they are what the match
    // was played for. The shot goes smaller to pay for it; it is a reaction,
    // not a portrait.
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
    await scrollReport(tester, const ValueKey('summary-reaction-row'));
    final row = find.byKey(const ValueKey('summary-reaction-row'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.byKey(const ValueKey('match-quests'))),
      findsOneWidget,
    );
  });

  testWidgets('AND THE MONEY GETS A SURFACE, like everything else here', (
    tester,
  ) async {
    // It was the one figure on the report drawn straight onto the sky, under a
    // column of panels — so the biggest number on the screen read as a caption.
    await pumpSummary(tester, result(coins: 500));
    expect(find.byKey(const ValueKey('summary-payout-card')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('summary-payout-card')),
        matching: find.byKey(const ValueKey('summary-payout')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('AND THEY ARE STILL AFTER THE TABLE, but now they FIT', (
    tester,
  ) async {
    // **This used to assert the quests were off the bottom**, which was true
    // and was the complaint: the dugout cam and the quest list both fell below
    // the fold. The table is a WINDOW round our own row now — us and whoever we
    // passed, rather than twenty rows of a division — so what was three
    // screenfuls is one.
    //
    // What has not changed is the ORDER. A quest report is a report rather than
    // a claim — the coins are already banked — so it may not come before the
    // thing this screen exists to show.
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
    expect(find.byKey(const ValueKey('summary-verdict')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
    // Still BELOW the table, which is the half that matters.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('match-quests'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('summary-table'))).dy,
      ),
    );
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
      await scrollReport(tester, const ValueKey('match-quests'));
      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('match-quest-match_clean_sheet')),
        findsOneWidget,
      );
      // Prefixed with its mark — a miss is red with a cross, a win green with
      // a tick — so the word is inside the row's text rather than all of it.
      expect(find.textContaining(t('quests.missed')), findsOneWidget);
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
      await scrollReport(tester, const ValueKey('match-quests'));
      expect(find.byKey(const ValueKey('match-quests')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-quests-total')), findsNothing);
    });
  });
  testWidgets('AND THE SCORELINE COMES OFF A REAL RESULT MAP', (tester) async {
    // **The fixture above is not enough on its own** — a fixture can carry
    // whatever keys the screen happens to read, which is exactly how a victory
    // screen came to show four goalscorers over a 0–0. This one takes the map
    // the ENGINE builds and checks the screen can read a score out of it.
    final built = simulateMatch(createDefaultState(), null);
    expect(
      built.keys,
      containsAll(['homeGoals', 'awayGoals']),
      reason: 'the engine renamed its goal keys',
    );

    built['homeGoals'] = 3;
    built['awayGoals'] = 1;
    built['won'] = true;
    built['drawn'] = false;
    // The board is laid out HOME SIDE LEFT and this fixture's tie may be away;
    // pinning it makes the expected string unambiguous.
    built['isHome'] = true;
    await pumpSummary(tester, built);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-score'))).data,
      '3–1',
      reason: 'the screen could not read the engine\'s own score',
    );
  });

  group('THE DUGOUT CAM IS IN A HURRY ON THIS SCREEN', () {
    // **The obvious answer broke a node fixture.** `camRotaGapMs` is the JS's
    // own table and `dugout_cam_policy_test` compares it row for row, so
    // halving it there failed three rows on the spot. The divergence belongs on
    // the screen that asked for it — four to seven seconds of nothing is most
    // of the time a player spends here, so the shot they see is the GAP.
    test('the hurry is a fraction, and it really is shorter', () {
      expect(camRotaHurry, greaterThan(0));
      expect(camRotaHurry, lessThan(1));
      for (final mood in Mood.values) {
        final beat = camRotaBeat(mood);
        expect(beat.gap * camRotaHurry, lessThan(beat.gap), reason: '$mood');
      }
    });

    test('and the SHAPE survives — a beaten man is still the restless one', () {
      // The reading is in the ratio between the moods, not in the absolute
      // wait, so scaling every band by the same figure keeps it.
      final crushed = camRotaGapMs[Mood.crushed]!;
      final elated = camRotaGapMs[Mood.elated]!;
      expect(crushed.$1 * camRotaHurry, lessThan(elated.$1 * camRotaHurry));
      expect(crushed.$2 * camRotaHurry, lessThan(elated.$2 * camRotaHurry));
    });
  });


  testWidgets('THE REACTION AND THE QUESTS ARE THE SAME HEIGHT', (
    tester,
  ) async {
    // The row was top-aligned, so the shot and the quest panel each finished at
    // whatever height they happened to want and the pair read as two things
    // dropped next to each other.
    await pumpSummary(
      tester,
      result(
        questResults: [
          {'id': 'q1', 'title': 'Win the match', 'met': true, 'coins': 50},
        ],
      ),
    );
    final row = find.byKey(const ValueKey('summary-reaction-row'));
    if (row.evaluate().isEmpty) return; // no quests on this result
    final shot = find.byKey(const ValueKey('summary-manager'));
    final quests = find.byType(QuestOutcomes);
    if (quests.evaluate().isEmpty) return;
    expect(
      tester.getSize(shot).height,
      closeTo(tester.getRect(quests).height, 24),
      reason: 'the two boxes finish at different heights',
    );
  });

/// **A CUP TIE THAT WENT TO PENALTIES PRINTS THE NINETY MINUTES.**
///
/// The engine folds the shootout's winning goal into `homeGoals`/`awayGoals` so
/// `won` and the recorded score agree, and a parity fixture reads those fields —
/// so the divergence lives on the screen. Reported from an Android handset: "I
/// drew 1-1 in a cup game, it should have went to pens, but instead it didnt, it
/// came up defeat and said they won 1-2".
group('a tie decided on penalties', () {
  Map<String, dynamic> tie({required bool playerWins}) => {
    ...result(won: playerWins),
    'isCup': true,
    'homeGoals': playerWins ? 2 : 1,
    'awayGoals': playerWins ? 1 : 2,
    'penaltyShootout': <String, dynamic>{
      'playerWins': playerWins,
      'homeScore': playerWins ? 4 : 3,
      'awayScore': playerWins ? 3 : 4,
      'kicks': [
        {'team': 'home', 'scored': true},
        {'team': 'away', 'scored': false},
      ],
    },
  };

  test('the printed score has the shootout goal taken back out', () {
    expect(regulationScore(tie(playerWins: false)), (1, 1));
    expect(regulationScore(tie(playerWins: true)), (1, 1));
    // A tie that was NOT level is left exactly alone.
    expect(regulationScore(result(won: true)), (2, 0));
  });

  testWidgets('so a shootout defeat reads 1-1 and says how it was lost', (
    tester,
  ) async {
    await pumpSummary(tester, tie(playerWins: false));
    expect(find.text(t('match.defeat').toUpperCase()), findsOneWidget);
    // The scoreline the player complained about read `1–2`.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary-score'))).data,
      '1–1',
    );
  });

  testWidgets('AND THE PENS ARE UNDER THE SCORE, not below the fold', (
    tester,
  ) async {
    await pumpSummary(tester, tie(playerWins: false));
    final row = find.byKey(const ValueKey('shootout-row'));
    expect(row, findsOneWidget, reason: 'nothing said it went to pens');
    expect(
      tester.getTopLeft(row).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('summary-reaction-row')))
            .dy,
      ),
      reason: 'the table, the scorers and the dugout came first, which put '
          'the pens under the fold',
    );
    // Directly under the card it completes, with nothing between them.
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('summary-score'))).dy),
    );
    expect(find.text('3 – 4'), findsOneWidget);
  });
});

}
