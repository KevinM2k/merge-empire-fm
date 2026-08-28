/// The quests sheet, and the menu that reaches it.
///
/// The toast said "claim it in Quests!" and there was no Quests: shipped copy
/// pointing at nothing, and a completed quest nobody could claim.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

/// A real SEASON quest. The bank's first entry is a MATCH one, and putting that
/// in the season track had the same id keyed twice once the match track started
/// rolling — which is the shape of save no real game can produce.
String get _questId => questBank.firstWhere((q) => q.scope == 'season').id;

Map<String, dynamic> saveWithQuests({
  bool completed = false,
  bool claimed = false,
  bool none = false,
  String? division,
}) {
  final s = createDefaultState();
  // A quest's payout is a percentage of one league win, so the DIVISION is what
  // decides whether the figure is big enough to abbreviate — see
  // `questRewardCoins`.
  if (division != null) {
    (s['progression'] as Map<String, dynamic>)['currentDivision'] = division;
  }
  // No boot popup competing for the screen.
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': 1,
    'lastClaimDayKey': dateString(),
    'streak': 1,
    'longestStreak': 1,
    'totalClaims': 1,
    'lastAutoPopupDayKey': dateString(),
  };
  s['quests'] = <String, dynamic>{
    'season': none
        ? <dynamic>[]
        : [
            <String, dynamic>{
              'id': _questId,
              'target': 10,
              'progress': completed ? 10 : 3,
              'completed': completed,
              'claimedAt': claimed ? 1 : null,
            },
          ],
    'match': <String, dynamic>{'fixtureKey': null, 'active': <dynamic>[]},
  };
  return s;
}

Future<ProviderContainer> pumpShell(
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
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          // The home screen's walker loops forever, so `pumpAndSettle` would
          // never settle. He honours reduce-motion; declaring it here is what a
          // device with that setting on would do.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),

          home: const AppShell(),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 32));
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

Future<void> openQuests(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('dock-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('quick-nav-quests.title')));
  await tester.pumpAndSettle();
  // Opening it rolls the track for the next match, which is a real write — so
  // there is a debounced save to let land.
  await settleSave(tester);
}

void main() {
  tearDown(() {
    resetPopupQueue();
    resetLocale();
  });

  testWidgets('the quick-nav menu now leads somewhere', (tester) async {
    // It was built with the other two shapes and nothing ever showed it.
    await pumpShell(tester, saveWithQuests());
    await tester.tap(find.byKey(const ValueKey('dock-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-nav')), findsOneWidget);
    // The tile labels are CAPS now, like every other nav label.
    expect(find.text(t('quests.title').toUpperCase()), findsWidgets);
  });

  testWidgets('and Quests opens from it', (tester) async {
    await pumpShell(tester, saveWithQuests());
    await openQuests(tester);
    expect(find.byKey(const ValueKey('quests-sheet')), findsOneWidget);
    expect(find.byKey(ValueKey('quest-season-$_questId')), findsOneWidget);
  });

  testWidgets('an unfinished quest shows progress and cannot be claimed', (
    tester,
  ) async {
    await pumpShell(tester, saveWithQuests());
    await openQuests(tester);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.byKey(ValueKey('quest-claim-season-$_questId')), findsNothing);
  });

  testWidgets('a finished one can be claimed, and pays', (tester) async {
    final container = await pumpShell(tester, saveWithQuests(completed: true));
    await openQuests(tester);

    final before = container.read(coinsProvider);
    await tester.tap(find.byKey(ValueKey('quest-claim-season-$_questId')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(coinsProvider), greaterThan(before));
    expect(container.read(claimableQuestsProvider), 0);
  });

  testWidgets('an already-claimed one offers nothing', (tester) async {
    await pumpShell(tester, saveWithQuests(completed: true, claimed: true));
    await openQuests(tester);
    expect(find.byKey(ValueKey('quest-claim-season-$_questId')), findsNothing);
    expect(find.byKey(ValueKey('quest-done-season-$_questId')), findsOneWidget);
  });

  testWidgets('an empty season track says so', (tester) async {
    await pumpShell(tester, saveWithQuests(none: true));
    await openQuests(tester);
    expect(find.byKey(const ValueKey('quests-none-season')), findsOneWidget);
  });

  group('WHAT IT PAYS', () {
    testWidgets('every quest names its reward, and so does the track', (
      tester,
    ) async {
      // The sheet listed the work and never the pay — not for one quest and
      // not for the set — so a season's quests read as a chore list.
      final container = await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      final row = container.read(seasonQuestsProvider).single;
      expect(row.coins, greaterThan(0), reason: 'the row carries no reward');
      expect(
        find.byKey(ValueKey('quest-reward-season-$_questId')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('quests-track-prize')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quests-track-coins')),
        findsOneWidget,
        reason: 'the track never says what finishing it is worth',
      );
      // The division capstone: the only gem in the game that is not a
      // purchase, and nothing on screen mentioned it.
      expect(find.byKey(const ValueKey('quests-track-gem')), findsOneWidget);
      expect(find.text(t('quests.capstone_reward', {'n': 1})), findsOneWidget);
    });

    testWidgets('AND THE FIGURE IS FORMATTED, not printed digit by digit', (
      tester,
    ) async {
      // `{n}` was the raw integer, so a season reward read "52000 coins" — a
      // number the eye has to count the digits on, on a chip 40px wide.
      // Reported straight off the screen, along with wanting the `.0` gone when
      // the figure lands on a whole thousand.
      final container = await pumpShell(
        tester,
        saveWithQuests(division: 'champions_cup'),
      );
      await openQuests(tester);
      final coins = container.read(seasonQuestsProvider).single.coins;
      expect(
        coins,
        greaterThanOrEqualTo(10000),
        reason: 'below 10k nothing abbreviates and the test proves nothing',
      );
      // Twice, not once: a single-quest track pays exactly what its one quest
      // does, so the row chip and the track chip carry the same figure.
      expect(
        find.text(
          t('quests.reward_coins', {'n': formatCoins(coins, trim: true)}),
        ),
        findsWidgets,
      );
      // And the long way round is nowhere on the sheet.
      expect(find.textContaining('$coins'), findsNothing);
    });

    /// **THE CHIP PAINTS ITS OWN DARK PLATE, so it takes the DARK theme's
    /// gold.** It used to ask `coinFigureInk`, which answers the deep bronze
    /// `gameGoldLight` on a light page — a shade that exists for gold on WHITE.
    /// On the charcoal plate this chip draws for itself that is brown on
    /// near-black, which is what the playtest reported.
    testWidgets('and the figure is GOLD on the plate, not bronze', (
      tester,
    ) async {
      await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      final ink = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('quests-track-coins')),
              matching: find.byType(Text),
            ),
          )
          .single
          .style!
          .color;
      expect(ink, gameGold);
      expect(ink, isNot(gameGoldLight));
    });

    testWidgets('and a division that has already paid its gem stops offering '
        'it', (tester) async {
      final state = saveWithQuests();
      state['gemGrants'] = <String, dynamic>{
        'questDivisionFirsts': [
          (state['progression'] as Map<String, dynamic>)['currentDivision'],
        ],
      };
      await pumpShell(tester, state);
      await openQuests(tester);
      expect(find.byKey(const ValueKey('quests-track-prize')), findsOneWidget);
      expect(find.byKey(const ValueKey('quests-track-gem')), findsNothing);
    });

    testWidgets('the track counts what has been banked', (tester) async {
      await pumpShell(tester, saveWithQuests(completed: true, claimed: true));
      await openQuests(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('quests-track-progress')))
            .data,
        '1 / 1',
      );
    });
  });

  group('the badge', () {
    // A dot on the burger rather than a count, which is what the JS shows: it
    // is the OR of every tile behind it, so a number would have to mean the sum
    // of several unrelated things.
    testWidgets('lights when something is waiting to be claimed', (
      tester,
    ) async {
      final container = await pumpShell(
        tester,
        saveWithQuests(completed: true),
      );
      expect(container.read(claimableQuestsProvider), 1);
      expect(find.byKey(const ValueKey('quick-nav-badge')), findsOneWidget);
    });

    testWidgets('and counts the daily and the drills, not just quests', (
      tester,
    ) async {
      // The burger's dot is the OR of every tile's own, so nothing that used to
      // nag from the scene goes quiet just because it moved a tap deeper. It had
      // only counted quests, which left a ready drill and an unclaimed daily
      // reward — both of them owed to the player — saying nothing at all.
      final container = await pumpShell(tester, saveWithQuests());
      // Nothing to CLAIM on the quest track...
      expect(container.read(claimableQuestsProvider), 0);
      // ...but a fresh save has its training drills charged, and a drill you can
      // play is a thing owed to the player just as much as a claimable quest.
      expect(container.read(miniGamesReadyProvider), greaterThan(0));
      expect(find.byKey(const ValueKey('quick-nav-badge')), findsOneWidget);
    });
  });

  group('the match track', () {
    testWidgets('is rolled when the sheet is opened', (tester) async {
      // `rollMatchQuests` had no caller, so the match track was empty for every
      // match ever played — three quests a fixture, none of them drawn.
      final container = await pumpShell(tester, saveWithQuests());
      final before =
          ((container.read(gameProvider).state!['quests']
                      as Map<String, dynamic>)['match']
                  as Map<String, dynamic>)['active']
              as List;
      expect(before, isEmpty);

      await openQuests(tester);
      final after =
          ((container.read(gameProvider).state!['quests']
                      as Map<String, dynamic>)['match']
                  as Map<String, dynamic>)['active']
              as List;
      expect(after.length, matchQuestCount);
      // The TRACK is rolled here; the sheet no longer SHOWS it. Match quests
      // read on the next-match card, where the fixture they belong to is — see
      // `MatchQuestsBlock`.
      expect(find.text(t('quests.match')), findsNothing);
    });

    testWidgets('and the sheet carries the SEASON track only', (tester) async {
      // A match quest pays itself at full time, so there was never anything to
      // claim on one — and reading it after choosing to open a menu is reading
      // it too late. It lives on the next-match card now.
      await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      expect(find.byKey(const ValueKey('quests-match-auto')), findsNothing);
      // **AND THE HEADER IS THE TRACK'S NAME.** `quests.title` — the bare word
      // "Quests" — used to head the sheet with `quests.season` repeated as a
      // subtitle under it: two headings for one list, on a sheet that has only
      // shown the season track since the match one moved to the next-match
      // card.
      expect(find.text(t('quests.season').toUpperCase()), findsOneWidget);
      expect(find.text(t('quests.title')), findsNothing);
    });

    testWidgets('opening it twice does not redraw the set just read', (
      tester,
    ) async {
      final container = await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      List<String> ids() => [
        for (final q
            in (((container.read(gameProvider).state!['quests']
                            as Map<String, dynamic>)['match']
                        as Map<String, dynamic>)['active']
                    as List)
                .cast<Map<String, dynamic>>())
          '${q['id']}',
      ];
      final first = ids();

      // Tap the barrier above the sheet to dismiss it, then come back.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await openQuests(tester);
      expect(ids(), first);
    });
  });

  group('the reroll', () {
    testWidgets('offers the free swaps a season comes with', (tester) async {
      await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      expect(find.byKey(const ValueKey('quests-reroll')), findsOneWidget);
      expect(find.byKey(const ValueKey('quests-reroll-free')), findsOneWidget);
      expect(find.textContaining(t('quests.reroll_free')), findsWidgets);
    });

    testWidgets('swaps the unfinished quest for a different one', (
      tester,
    ) async {
      final container = await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('quests-reroll')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quests-reroll')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      final ids = [
        for (final q
            in ((container.read(gameProvider).state!['quests']
                        as Map<String, dynamic>)['season']
                    as List)
                .cast<Map<String, dynamic>>())
          '${q['id']}',
      ];
      expect(ids, isNot(contains(_questId)));
      expect(ids, hasLength(1), reason: 'swapped, not added to');
    });

    testWidgets('refuses when there is nothing left to swap', (tester) async {
      // Charging for a reroll that could change nothing would be theft.
      await pumpShell(tester, saveWithQuests(completed: true, claimed: true));
      await openQuests(tester);
      expect(
        tester
            .widget<StoreButton>(find.byKey(const ValueKey('quests-reroll')))
            .onTap,
        isNull,
      );
    });
  });

  group('the tiles look like three different things', () {
    testWidgets('A QUEST WEARS ITS PROGRESS AS A RING, not a bar', (
      tester,
    ) async {
      // The tile was a line of text, a full-width bar and a fraction — the same
      // three rows whether the quest was untouched, half done, or had money
      // waiting on it. A bar under the text says what the fraction beside it
      // already said; round the medallion it is the same reading in no extra
      // height.
      await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      final tile = find.byKey(ValueKey('quest-season-$_questId'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
      );
    });

    testWidgets('a LIVE one is the sheet\'s plain surface', (tester) async {
      await pumpShell(tester, saveWithQuests());
      await openQuests(tester);
      final kit = Theme.of(
        tester.element(find.byKey(ValueKey('quest-season-$_questId'))),
      ).extension<KitTheme>()!;
      expect(
        tester
            .widget<Card>(find.byKey(ValueKey('quest-season-$_questId')))
            .color,
        kit.surface,
      );
    });

    testWidgets('and a CLAIMABLE one is the only one with colour in it', (
      tester,
    ) async {
      // It is the one thing on the sheet with something owed on it. Same
      // surface as the other two and it has to be hunted for.
      await pumpShell(tester, saveWithQuests(completed: true));
      await openQuests(tester);
      expect(
        find.byKey(ValueKey('quest-claim-season-$_questId')),
        findsOneWidget,
        reason: 'this save is not claimable, so the test proves nothing',
      );
      final kit = Theme.of(
        tester.element(find.byKey(ValueKey('quest-season-$_questId'))),
      ).extension<KitTheme>()!;
      expect(
        tester
            .widget<Card>(find.byKey(ValueKey('quest-season-$_questId')))
            .color,
        isNot(kit.surface),
      );
    });
  });

  testWidgets('THE SHEET IS AS TALL AS THE TRACK, not 80% of the phone', (
    tester,
  ) async {
    // Reported from the couch: too big, too much room at the bottom. A
    // `ListView` fills what it is given, so three quests sat at the top of a
    // sheet sized to the screen. `heightFraction` is a ceiling now — see
    // `bottom_sheet_popup.dart` and the spec's `height: auto` on `.ps-sheet`.
    await pumpShell(tester, saveWithQuests());
    await openQuests(tester);
    final sheet = tester
        .getSize(find.byKey(const ValueKey('bottom-sheet-popup')))
        .height;
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      sheet,
      lessThan(screen * 0.8),
      reason: 'back to filling the ceiling',
    );
    expect(
      sheet,
      closeTo(
        tester.getSize(find.byKey(const ValueKey('quests-sheet'))).height,
        24,
      ),
      reason: 'the sheet is the list plus its own chrome, and nothing else',
    );
  });
}
