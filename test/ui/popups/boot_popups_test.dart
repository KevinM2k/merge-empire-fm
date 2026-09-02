/// What the game shows the moment it opens.
///
/// The queue and its guarantees were built and NOTHING ever queued into it, so
/// the welcome-back card and the daily reward were both unreachable. These are
/// the tests that would have caught that.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/engine/idle_engine.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/popup_host.dart';
import 'package:merge_empire_fc/ui/popups/welcome_back_card.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> saveWith({
  bool claimedToday = false,
  bool withPlayers = false,
  int? lastSeen,
}) {
  final s = createDefaultState();
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': claimedToday ? 1 : 0,
    'lastClaimDayKey': claimedToday ? dateString() : null,
    'streak': claimedToday ? 1 : 0,
    'longestStreak': 0,
    'totalClaims': claimedToday ? 1 : 0,
    'lastAutoPopupDayKey': null,
  };
  if (lastSeen != null) s['lastSeen'] = lastSeen;
  if (withPlayers) {
    final def = players.firstWhere((p) => p.tier == 1);
    final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
    for (var i = 0; i < 5; i++) {
      cells[i] = <String, dynamic>{
        'definitionId': def.id,
        'instanceId': 'c$i',
        'variant': 0,
      };
    }
  }
  return s;
}

Future<ProviderContainer> boot(
  WidgetTester tester,
  Map<String, dynamic> state, {
  bool load = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  // **THROUGH THE RUNNER, not `game.load()`.** The offline window is read
  // inside `GameRunner.boot`, at the instant the save is loaded and before any
  // sweep can stamp `lastSeen` over it — so a test that loads the save by hand
  // has no reading for the host to show, and the welcome-back card never
  // opens. Which is the shape of the bug it is here to catch.
  if (load) container.read(gameRunnerProvider).boot();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: const PopupHost(child: Scaffold(body: SizedBox.expand())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Every claim arms the 2s debounced save.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  testWidgets('an unclaimed daily reward is offered at boot', (tester) async {
    // A SHEET, not a coach card: the cycle is the thing worth showing, and the
    // card it used to be said "Day 3" and nothing else.
    await boot(tester, saveWith());
    expect(find.byKey(const ValueKey('daily-reward-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-claim')), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-streak')), findsOneWidget);
  });

  testWidgets('and it shows the whole week, day seven included', (
    tester,
  ) async {
    // Day seven pays the only recurring gems in the game. A popup that does not
    // show it is a login reward with its payoff hidden.
    await boot(tester, saveWith());
    for (var day = 1; day <= cycleDays; day++) {
      expect(
        find.byKey(ValueKey('daily-day-$day')),
        findsOneWidget,
        reason: 'day $day',
      );
    }
  });

  testWidgets('claiming it pays, says what it paid, and is not offered twice', (
    tester,
  ) async {
    final container = await boot(tester, saveWith());
    final before = container.read(coinsProvider);

    await tester.tap(find.byKey(const ValueKey('daily-claim')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(coinsProvider), greaterThan(before));
    // Still up, reporting what arrived — a reward that vanishes as it is taken
    // is one the player never saw.
    expect(find.byKey(const ValueKey('daily-items')), findsOneWidget);

    // **NO CLOSE BUTTON ANY MORE** — the sheet is dismissed by tapping outside
    // it, which is what the line at the bottom now says rather than offers.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('daily-reward-sheet')), findsNothing);
    expect(hasPopupWork(), isFalse);
  });

  testWidgets('THE AD DOUBLE IS LIVE', (tester) async {
    // The grant was always the engine's own `doubled` flag; what was missing
    // was the video, and `daily_double` has been a real unit id with no caller
    // the whole time.
    await boot(tester, saveWith());
    expect(
      tester
          .widget<StoreButton>(find.byKey(const ValueKey('daily-claim-double')))
          .onTap,
      isNotNull,
    );
  });

  testWidgets('an already-claimed day offers nothing', (tester) async {
    await boot(tester, saveWith(claimedToday: true));
    expect(find.byKey(const ValueKey('daily-reward-sheet')), findsNothing);
  });

  testWidgets('AND ONCE A DAY, not on every boot until it is taken', (
    tester,
  ) async {
    // The gate was `!claimedToday`, so a player who opened the app, read the
    // cycle and closed it without claiming was shown it again on the next boot
    // and the one after that. `shouldAutoShowPopup` stamps the day as it goes
    // — the engine's own once-a-day rule, which had no caller.
    // Tall enough for the sheet's own Close to be on screen: the cycle is seven
    // tiles and a claim row, and the default 600 leaves the button below the
    // fold where a tap cannot reach it.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final first = await boot(tester, saveWith());
    expect(find.byKey(const ValueKey('daily-reward-sheet')), findsOneWidget);

    // Closed WITHOUT claiming, which is the case the gate is about.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(hasPopupWork(), isFalse);

    // The save the first boot leaves behind, which is what a second launch
    // would load. `boot` encodes its argument, so the state the flow mutated is
    // the container's, not the fixture's.
    final after = first.read(gameProvider).state!;
    expect(
      getDailyRewardStatus(after).claimedToday,
      isFalse,
      reason: 'the sheet was opened, not claimed — that is the whole case',
    );
    expect(
      (after['dailyReward'] as Map)['lastAutoPopupDayKey'],
      dateString(),
      reason: 'the auto-open has to say it happened, or it happens forever',
    );

    await boot(tester, after);
    expect(
      find.byKey(const ValueKey('daily-reward-sheet')),
      findsNothing,
      reason: 'offered a second time on the same day',
    );
  });

  testWidgets('and the burger opens it anyway, gate or no gate', (
    tester,
  ) async {
    // The JS's rule in as many words: a manual open bypasses the auto gate
    // entirely. A day already auto-shown must still be reachable, or the one
    // way to claim it is gone until midnight.
    final save = saveWith();
    (save['dailyReward'] as Map)['lastAutoPopupDayKey'] = dateString();
    expect(shouldAutoShowPopup(save), isFalse);
    expect(
      getDailyRewardStatus(save).claimedToday,
      isFalse,
      reason: 'the gate must not be mistaken for having been paid',
    );
  });

  testWidgets('offline earnings are offered, and paid on Collect', (
    tester,
  ) async {
    // The card holds coins that exist NOWHERE else: boot stamps lastSeen, so if
    // the card never shows, those earnings are simply gone.
    final container = await boot(
      tester,
      saveWith(claimedToday: true, withPlayers: true, lastSeen: 1),
    );
    expect(find.byKey(const ValueKey('welcome-back')), findsOneWidget);

    final before = container.read(coinsProvider);
    await tester.tap(find.byKey(const ValueKey('welcome-back-collect')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(
      container.read(coinsProvider),
      greaterThan(before),
      reason: 'applied on Collect, so the HUD animates when asked',
    );
  });

  testWidgets('the coins come FIRST, the streak second', (tester) async {
    // The queue's own priority, and the reason it has one.
    await boot(tester, saveWith(withPlayers: true, lastSeen: 1));
    expect(activePopupId(), 'welcome-back');

    await tester.tap(find.byKey(const ValueKey('welcome-back-collect')));
    await settleSave(tester);
    await tester.pumpAndSettle();
    expect(activePopupId(), 'daily-reward');
  });

  testWidgets('A SHORT ABSENCE PAYS, BUT DOES NOT INTERRUPT', (tester) async {
    // **Reported from the couch: the card comes up after watching an ad.** It
    // did — "is anything owed" was the only gate, and thirty seconds of a
    // rewarded video earns something as soon as the squad has any income, so
    // the game welcomed the player back from a video it had shown them itself.
    final container = await boot(
      tester,
      saveWith(
        claimedToday: true,
        withPlayers: true,
        // Half the floor: an ad break, a text message, the shade.
        lastSeen: DateTime.now().millisecondsSinceEpoch - welcomeBackFloorMs ~/ 2,
      ),
    );
    expect(find.byKey(const ValueKey('welcome-back')), findsNothing);
    await settleSave(tester);
    // And the coins are still paid. `lastSeen` has already been stamped, so a
    // window that closes without paying has burned them.
    expect(container.read(coinsProvider), greaterThan(0));
  });

  testWidgets('a club with no players is owed no offline earnings', (
    tester,
  ) async {
    // Nothing was earning while they were away.
    await boot(tester, saveWith(claimedToday: true, lastSeen: 1));
    expect(find.byKey(const ValueKey('welcome-back')), findsNothing);
  });

  group('what the welcome-back card says', () {
    /// **A SCOPE, because the typewriter reads one.** Colin's line holds while
    /// anything is over the card and `screenIsCoveredProvider` is what answers
    /// that, so a card mounted with no `ProviderScope` throws "No ProviderScope
    /// found" out of `build` — which is what these five were doing. The coach
    /// card's own harness has carried the same wrapper, and the note saying
    /// why, since the provider went in.
    Future<void> pumpCard(WidgetTester tester, OfflineEarnings offline) =>
        tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildAppTheme(kitId: '#4caf50', light: false),
              home: Scaffold(body: WelcomeBackCard(offline: offline)),
            ),
          ),
        );

    testWidgets('the number, which the old card never mentioned', (
      tester,
    ) async {
      await pumpCard(tester, (earned: 12500, offlineMs: 3600000));
      expect(find.textContaining(formatCoins(12500)), findsOneWidget);
      expect(find.text(t('welcome.earned_label')), findsOneWidget);
    });

    testWidgets('and Colin\'s own line, from the pool', (tester) async {
      // `welcome.line` is five lines separated by pipes and was unreachable —
      // the card used `welcome.earned_label` for its title AND its body.
      await pumpCard(tester, (earned: 100, offlineMs: 3600000));
      // `Text.rich`, not `Text`: his line is TYPED, and the tail that has not
      // arrived yet is a transparent span rather than an absent one — so the
      // whole sentence is laid out and readable off the widget from the first
      // frame. See `CoachTypewriter`.
      final line = tester
          .widget<Text>(find.byKey(const ValueKey('welcome-back-line')))
          .textSpan!
          .toPlainText();
      expect(line, isNot(contains('|')), reason: 'one line, not all five');
      final pool = t('welcome.line', {'duration': proseDuration(3600000)});
      expect(
        pool.split('|').map((l) => l.trim()),
        contains(line),
        reason: 'and the duration is filled in',
      );
      expect(find.text(t('app.offline_title')), findsOneWidget);
    });

    testWidgets('the duration reads as prose, not as a stat row', (
      tester,
    ) async {
      // `formatDuration` always emits both units, and the 8-hour cap makes
      // "8h 0m" the most common thing this card ever says.
      expect(proseDuration(8 * 3600000), '8h');
      expect(proseDuration(90 * 60000), formatDuration(90 * 60000));
    });

    testWidgets('and the CEILING is flagged when the absence hit it', (
      tester,
    ) async {
      // `processOfflineEarnings` clamps the window, so three days away arrives
      // as eight hours with nothing saying the books had stopped counting.
      await pumpCard(tester, (earned: 100, offlineMs: Idle.maxOfflineMs));
      expect(find.byKey(const ValueKey('welcome-back-capped')), findsOneWidget);
      expect(
        find.textContaining(
          t('welcome.note_capped', {'hours': offlineCapHours}),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a short absence is not', (tester) async {
      await pumpCard(tester, (earned: 100, offlineMs: 60000));
      expect(find.byKey(const ValueKey('welcome-back-capped')), findsNothing);
    });

    testWidgets('and he arrives through his OWN chrome, not a second one', (
      tester,
    ) async {
      // This was an `AlertDialog` carrying its own disc, its own name plate and
      // its own type sizes: the one card every single launch opens with was
      // also the one card Colin turned up in a different window on. It stands
      // on the shared stage now — the bottom-anchored box he stands behind.
      await pumpCard(tester, (earned: 100, offlineMs: 3600000));
      expect(find.byType(CoachStage), findsOneWidget);
      expect(find.byType(CoachStandee), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  testWidgets('a boot with no save loaded offers nothing at all', (
    tester,
  ) async {
    // Treating an absent save as "unclaimed" would offer the reward twice.
    await boot(tester, saveWith(), load: false);
    expect(find.byKey(const ValueKey('welcome-back')), findsNothing);
    expect(hasPopupWork(), isFalse);
  });
}
