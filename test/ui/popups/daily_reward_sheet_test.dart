/// The daily reward, as the player meets it.
///
/// The port showed a coach card reading "Day 3" with a Claim button —
/// `getDailyRewardPreview` and `canRepairStreak` were both ported with no
/// caller, so the cycle and the broken-streak branch were invisible.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show hudCoinInk;
import 'package:merge_empire_fc/ui/popups/daily_reward_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/time.dart';

const int _dayMs = 24 * 60 * 60 * 1000;

/// A save whose streak stands where the test needs it.
///
/// `lastClaimDayKey` is the whole story: yesterday continues the cycle, two days
/// ago breaks it, and today means it is already claimed.
Map<String, dynamic> save({
  int? lastClaimDaysAgo = 1,
  int streak = 3,
  int cycleDay = 3,
  bool trainedYesterday = false,
  bool pro = false,
}) {
  final s = createDefaultState();
  (s['settings'] as Map<String, dynamic>)['hardMode'] = pro;
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': cycleDay,
    'lastClaimDayKey': lastClaimDaysAgo == null
        ? null
        : dateString(now() - lastClaimDaysAgo * _dayMs),
    'streak': streak,
    'longestStreak': streak,
    'totalClaims': streak,
    'lastAutoPopupDayKey': null,
  };
  if (trainedYesterday) {
    s['miniGames'] = <String, dynamic>{'penaltyLastPlayed': now() - _dayMs};
  }
  return s;
}

/// A stand-in SDK. Both offers on this sheet are rewarded videos now.
class FakeAds implements RewardedAds {
  FakeAds([this.outcome = AdOutcome.rewarded]);

  AdOutcome outcome;
  final List<String> shown = [];

  @override
  Future<AdOutcome> show(String placement) async {
    shown.add(placement);
    return outcome;
  }

  @override
  void prepare(String placement) {}
}

Future<ProviderContainer> pumpSheet(
  WidgetTester tester,
  Map<String, dynamic> state, {
  RewardedAds? ads,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
      if (ads != null) rewardedAdsProvider.overrideWithValue(ads),
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
          home: const Scaffold(body: DailyRewardSheet()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

void main() {
  tearDown(resetLocale);

  group('one day of the cycle, in a line', () {
    test('names the coins every day carries', () {
      final reward = getDailyRewardPreview(save(), 1)!;
      expect(dayRewardLine(reward), isNotEmpty);
    });

    test('and only mentions the extras a day actually has', () {
      // Day one is coins alone; day seven is the gem day. The rewards are typed
      // now rather than joined into a string, so the day is asked which WALLETS
      // it pays into — the emoji were what the icons replaced.
      final plain = getDailyRewardPreview(save(), 1)!;
      final seventh = getDailyRewardPreview(save(), 7)!;
      List<String?> icons(DailyRewardPreview r) =>
          [for (final p in dayRewardParts(r)) p.icon];
      expect(icons(plain), ['coin']);
      expect(icons(seventh), containsAll(<String>['coin', 'bolt', 'gem']));
    });
  });

  group('the sheet', () {
    testWidgets('shows the week, the streak and today', (tester) async {
      await pumpSheet(tester, save());
      for (var day = 1; day <= cycleDays; day++) {
        expect(find.byKey(ValueKey('daily-day-$day')), findsOneWidget);
      }
      expect(find.text(t('daily.streak', {'n': 3})), findsOneWidget);
      expect(find.text(t('daily.today')), findsOneWidget);
    });

    testWidgets('claiming reports what arrived and stops offering', (
      tester,
    ) async {
      final container = await pumpSheet(tester, save());
      final before = container.read(coinsProvider);

      await tester.tap(find.byKey(const ValueKey('daily-claim')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(container.read(coinsProvider), greaterThan(before));
      expect(find.byKey(const ValueKey('daily-items')), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-claim')), findsNothing);
    });

    testWidgets('a day already claimed says when to come back', (tester) async {
      await pumpSheet(tester, save(lastClaimDaysAgo: 0));
      expect(find.byKey(const ValueKey('daily-come-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-claim')), findsNothing);
    });

    testWidgets('training yesterday is worth saying', (tester) async {
      // It bumps the coin component, and the popup is where the player would
      // otherwise never learn that the two systems talk to each other.
      await pumpSheet(tester, save(trainedYesterday: true));
      expect(find.byKey(const ValueKey('daily-trained-bonus')), findsOneWidget);
    });

    testWidgets('and a day with no training does not', (tester) async {
      await pumpSheet(tester, save());
      expect(find.byKey(const ValueKey('daily-trained-bonus')), findsNothing);
    });
  });

  group('a broken streak', () {
    testWidgets('is explained, with both ways out', (tester) async {
      await pumpSheet(tester, save(lastClaimDaysAgo: 3));
      expect(find.byKey(const ValueKey('daily-broken')), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-repair')), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-start-over')), findsOneWidget);
      // The cycle is not shown yet: the question on screen is the streak.
      expect(find.byKey(const ValueKey('daily-day-1')), findsNothing);
    });

    testWidgets('THE REPAIR IS A REWARDED VIDEO, AND IT WORKS', (tester) async {
      // `streak_repair` has been a real unit id with no caller since the ad
      // units landed, and `repairStreak` a ported engine function with no
      // caller since before that — so the one way back from a broken streak
      // was present, dead, and explained.
      final ads = FakeAds();
      final container = await pumpSheet(
        tester,
        save(lastClaimDaysAgo: 3),
        ads: ads,
      );
      await tester.tap(find.byKey(const ValueKey('daily-repair')));
      await tester.pumpAndSettle();

      expect(ads.shown, ['streak_repair']);
      expect(
        find.byKey(const ValueKey('daily-broken')),
        findsNothing,
        reason: 'the streak was not put back',
      );
      await settleSave(tester);
      expect(container.read(gameProvider).state, isNotNull);
    });

    testWidgets('and a video closed early repairs NOTHING', (tester) async {
      // Backing out is a choice, not a fault: nothing is owed and nothing is
      // said.
      final ads = FakeAds(AdOutcome.dismissed);
      await pumpSheet(tester, save(lastClaimDaysAgo: 3), ads: ads);
      await tester.tap(find.byKey(const ValueKey('daily-repair')));
      await tester.pumpAndSettle();
      expect(ads.shown, ['streak_repair']);
      expect(find.byKey(const ValueKey('daily-broken')), findsOneWidget);
    });

    testWidgets('with no ad to show it says so and changes nothing', (
      tester,
    ) async {
      final ads = FakeAds(AdOutcome.unavailable);
      await pumpSheet(tester, save(lastClaimDaysAgo: 3), ads: ads);
      await tester.tap(find.byKey(const ValueKey('daily-repair')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('daily-broken')), findsOneWidget);
    });

    testWidgets('starting over goes on to the claim', (tester) async {
      await pumpSheet(tester, save(lastClaimDaysAgo: 3));
      await tester.tap(find.byKey(const ValueKey('daily-start-over')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('daily-broken')), findsNothing);
      expect(find.byKey(const ValueKey('daily-claim')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('daily-day-1')),
        findsOneWidget,
        reason: 'back at the start of the week',
      );
    });

    testWidgets('and a player with no streak to break never sees it', (
      tester,
    ) async {
      await pumpSheet(tester, save(lastClaimDaysAgo: null, streak: 0));
      expect(find.byKey(const ValueKey('daily-broken')), findsNothing);
      expect(find.byKey(const ValueKey('daily-claim')), findsOneWidget);
    });
  });

  group('THE CYCLE FILLS UP', () {
    testWidgets('a claimed day is ticked, and an unclaimed one is not', (
      tester,
    ) async {
      // The strip picked out today and marked nothing else, so a player four
      // days into a streak saw days one to three drawn exactly like days five to
      // seven: seven identical tiles with one border on them. Watching it fill
      // is the whole point of a cycle.
      final container = await pumpSheet(tester, save(cycleDay: 3));
      addTearDown(container.dispose);

      // Claimed yesterday, so today is day 4 and one to three are banked.
      for (final day in [1, 2, 3]) {
        expect(
          find.byKey(ValueKey('daily-claimed-$day')),
          findsOneWidget,
          reason: 'day $day is behind us and unmarked',
        );
      }
      for (final day in [4, 5, 6, 7]) {
        expect(
          find.byKey(ValueKey('daily-claimed-$day')),
          findsNothing,
          reason: 'day $day has not happened yet',
        );
      }
    });

    testWidgets('and claiming ticks TODAY off in front of you', (tester) async {
      final container = await pumpSheet(tester, save(cycleDay: 3));
      addTearDown(container.dispose);
      expect(find.byKey(const ValueKey('daily-claimed-4')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('daily-claim')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('daily-claimed-4')),
        findsOneWidget,
        reason: 'the day just claimed is still shown as owing',
      );
      await tester.pump(const Duration(milliseconds: 2100));
    });

    testWidgets('and a BROKEN streak has nothing banked', (tester) async {
      // It resets to day one, and nothing before day one exists — which is
      // exactly right: a streak that broke has nothing to show for itself.
      final container = await pumpSheet(
        tester,
        save(lastClaimDaysAgo: 3, cycleDay: 5),
      );
      addTearDown(container.dispose);
      for (var day = 1; day <= 7; day++) {
        expect(
          find.byKey(ValueKey('daily-claimed-$day')),
          findsNothing,
          reason: 'day $day is ticked on a broken streak',
        );
      }
    });
  });
  group('THE WEEK USES THE ROOM IT HAS', () {
    testWidgets('SEVEN EQUAL BOXES, and the row is as wide as the sheet', (
      tester,
    ) async {
      // They were fixed at 84px in a `Wrap`, so seven of them broke into a full
      // row and a short one centred under it — and on any phone wider than the
      // four that fitted, the strip left a third of the sheet empty rather than
      // growing.
      await pumpSheet(tester, save());
      final sizes = [
        for (var day = 1; day <= cycleDays; day++)
          tester.getSize(find.byKey(ValueKey('daily-day-$day'))),
      ];
      for (final size in sizes) {
        expect(size, sizes.first, reason: 'the boxes are not the same box');
      }

      // The top row spans the strip: four tiles and three gaps, edge to edge.
      final left = tester.getTopLeft(find.byKey(const ValueKey('daily-day-1')));
      final right = tester.getTopRight(
        find.byKey(const ValueKey('daily-day-4')),
      );
      final sheet = tester.getSize(find.byType(DailyRewardSheet));
      expect(
        right.dx - left.dx,
        // The sheet's own horizontal padding, both sides.
        closeTo(sheet.width - 36, 1),
        reason: 'the strip is narrower than the room it has',
      );
    });

    /// **THE COINS WERE THE ONLY THING WITH NO MARK ON THEM.** Energy has its
    /// bolt and gems have their stone, so a day paying 500 coins and 2 gems
    /// read as "500 · 2💎" — a bare number beside a labelled one. Reported
    /// from the couch as no coins next to the coins.
    ///
    /// **AND THEN AS AN EMOJI MONEY-BAG.** The mark it got was 💰, which is the
    /// one money glyph in the game not drawn in the set everything else is drawn
    /// in — so it is the app's own coin now, in the coin gold, and each reward
    /// sits in a box of its own.
    testWidgets('and the coins wear the app\'s own coin, in the coin gold', (
      tester,
    ) async {
      await pumpSheet(tester, save());
      final day = find.byKey(const ValueKey('daily-day-1'));
      expect(
        find.descendant(of: day, matching: find.textContaining('💰')),
        findsNothing,
      );
      final coin = tester.widget<GameIcon>(
        find.descendant(of: day, matching: find.byType(GameIcon)),
      );
      expect(coin.name, 'coin');
      expect(coin.color, hudCoinInk);
    });

    /// **ONE BOX PER REWARD.** The three figures were a single run of text
    /// joined with middots; the tile has the width for a pill each.
    testWidgets('and the gem day draws a box for every one of them', (
      tester,
    ) async {
      await pumpSheet(tester, save());
      final seventh = getDailyRewardPreview(save(), 7)!;
      expect(dayRewardParts(seventh).length, greaterThan(2));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('daily-day-7')),
          matching: find.byType(GameIcon),
        ),
        findsNWidgets(
          dayRewardParts(seventh).where((p) => p.icon != null).length,
        ),
      );
    });

    testWidgets('AND THE TICK CROSSES THE BOX', (tester) async {
      // It was an 11px glyph tucked in front of the day's label, at the size of
      // the caption beside it — so a claimed day and an unclaimed one read the
      // same from a foot away.
      await pumpSheet(tester, save(cycleDay: 4));
      final tick = tester.getSize(
        find.byKey(const ValueKey('daily-claimed-1')),
      );
      final tile = tester.getSize(find.byKey(const ValueKey('daily-day-1')));
      expect(
        tick.height,
        greaterThan(tile.height * 0.5),
        reason: 'the tick still sits in a corner',
      );
    });
  });
  group('THE STREAK IS THE HERO, not a caption', () {
    testWidgets('the figure is drawn at size, with the run beside it', (
      tester,
    ) async {
      // It is the one number on this sheet that is ABOUT the player rather than
      // about the prize — the cycle strip already says what today pays — and it
      // was a 12px grey line under the title on a sheet with room to spare.
      await pumpSheet(tester, save(streak: 6));
      expect(find.byKey(const ValueKey('daily-streak')), findsOneWidget);
      final figure = tester.widget<Text>(
        find.byKey(const ValueKey('daily-streak-figure')),
      );
      expect(figure.data, '6');
      expect(figure.style!.fontSize, greaterThan(24));
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('AND IT READS THE SAVE, which is what nothing did', (
      tester,
    ) async {
      // `getDailyStreak` went through two reachability audits with no caller in
      // `lib/` at all.
      await pumpSheet(tester, save(streak: 11));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('daily-streak-figure')))
            .data,
        '11',
      );
    });

    testWidgets('a run of nothing shows a nought and no flame', (tester) async {
      await pumpSheet(tester, save(streak: 0, lastClaimDaysAgo: null));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('daily-streak-figure')))
            .data,
        '0',
      );
      expect(find.text('🔥'), findsNothing);
    });
  });


  group('claiming at double', () {
    testWidgets('WATCHING IT THROUGH PAYS TWICE', (tester) async {
      final ads = FakeAds();
      final container = await pumpSheet(tester, save(), ads: ads);
      final before = (container.read(gameProvider).state!['resources']
          as Map<String, dynamic>)['fanCoins'] as num;

      await tester.tap(find.byKey(const ValueKey('daily-claim-double')));
      await tester.pumpAndSettle();
      expect(ads.shown, ['daily_double']);
      final doubled = (container.read(gameProvider).state!['resources']
          as Map<String, dynamic>)['fanCoins'] as num;
      expect(doubled, greaterThan(before));
      await settleSave(tester);
    });

    /// **AND IT LOOKS LIKE THE AD IT IS.** An `OutlinedButton` is the theme's
    /// moulded face with an empty middle and a grey edge bar, so the one button
    /// on the sheet that pays DOUBLE looked like the disabled state of
    /// something. Reported from the couch with the fix named.
    testWidgets('THE DOUBLE BUTTON IS THE AD COLOUR, and says AD', (
      tester,
    ) async {
      await pumpSheet(tester, save());
      final button = tester.widget<StoreButton>(
        find.byKey(const ValueKey('daily-claim-double')),
      );
      expect(button.tone, StoreTone.ad);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('daily-claim-double')),
          matching: find.text('AD'),
        ),
        findsOneWidget,
      );
      // And the plain claim is coloured for what it pays, not left grey.
      expect(
        tester
            .widget<StoreButton>(find.byKey(const ValueKey('daily-claim')))
            .tone,
        StoreTone.coin,
      );
    });

    testWidgets('AN UNAVAILABLE AD CLAIMS NOTHING AT ALL', (tester) async {
      // Not even at the single rate. The player asked for the doubled one, and
      // quietly giving them half of it spends their day's reward on a choice
      // they did not make — the single-rate button is still right there.
      final ads = FakeAds(AdOutcome.unavailable);
      final container = await pumpSheet(tester, save(), ads: ads);
      final before = (container.read(gameProvider).state!['resources']
          as Map<String, dynamic>)['fanCoins'] as num;

      await tester.tap(find.byKey(const ValueKey('daily-claim-double')));
      await tester.pumpAndSettle();
      expect(
        (container.read(gameProvider).state!['resources']
            as Map<String, dynamic>)['fanCoins'],
        before,
      );
      expect(find.byKey(const ValueKey('daily-claim')), findsOneWidget);
    });

    testWidgets('and backing out of one leaves the day unclaimed', (
      tester,
    ) async {
      final ads = FakeAds(AdOutcome.dismissed);
      await pumpSheet(tester, save(), ads: ads);
      await tester.tap(find.byKey(const ValueKey('daily-claim-double')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('daily-claim')), findsOneWidget);
    });
  });
}
