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
import 'package:merge_empire_fc/ui/hud/hud.dart'
    show hudBadgeColour, hudBadgeInk, hudCoinInk;
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
  group('THE WAIT IS A CLOCK, not a day number', () {
    test('the cycle turns over at LOCAL midnight, not 24h after the claim', () {
      // `_dayKey` is `dateString`, which is a local-time day — so claim at 23:55
      // and the next reward is five minutes away. A fixed 24 hours from the last
      // claim is a different answer by up to a day, and the wrong one.
      final lateEvening = DateTime(2026, 3, 14, 23, 55).millisecondsSinceEpoch;
      expect(
        msUntilNextReward(lateEvening),
        5 * 60 * 1000,
        reason: 'the countdown is measuring from the claim, not to midnight',
      );
      // And it normalises across a month end rather than adding 86,400,000.
      final monthEnd = DateTime(2026, 1, 31, 22, 0).millisecondsSinceEpoch;
      expect(msUntilNextReward(monthEnd), 2 * 60 * 60 * 1000);
    });

    testWidgets('a claimed day shows the running clock under the line', (
      tester,
    ) async {
      // What was here was one 12pt grey line naming a day number — the least
      // interesting true thing that could be said to somebody who has already
      // claimed and is being asked back. The shipped sentence is unchanged and
      // stays the label; the figure is what is new, and a figure needs no
      // translating.
      final container = await pumpSheet(tester, save(lastClaimDaysAgo: 0));
      addTearDown(container.dispose);
      expect(find.byKey(const ValueKey('daily-come-back')), findsOneWidget);
      final clock = find.byKey(const ValueKey('daily-countdown'));
      expect(clock, findsOneWidget);
      expect(
        tester.widget<Text>(clock).data,
        matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')),
        reason: 'the countdown is not a clock face',
      );
    });

    testWidgets('and the seconds actually move', (tester) async {
      // The timer lives on the countdown rather than on the sheet, so it exists
      // only while the clock is on screen — a timer on the parent would tick
      // through a claim and through the broken-streak card as well.
      //
      // **Driven through `setClock`, because the test binding's clock and the
      // app's are different clocks.** Pumping a second advances the SCHEDULER,
      // which is what fires the timer; `now()` is still the wall clock, so the
      // rebuild would read a figure a couple of real milliseconds later and
      // print the same second back. Moving the app's clock is what makes the
      // assertion about the countdown rather than about how long the test took.
      var fake = DateTime(2026, 3, 14, 9, 0).millisecondsSinceEpoch;
      setClock(() => fake);
      addTearDown(resetClock);
      final container = await pumpSheet(tester, save(lastClaimDaysAgo: 0));
      addTearDown(container.dispose);
      final clock = find.byKey(const ValueKey('daily-countdown'));
      expect(tester.widget<Text>(clock).data, '15:00:00');

      fake += 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<Text>(clock).data,
        '14:59:59',
        reason: 'the clock is a still picture of a countdown',
      );
    });
  });

  group('THE WEEK USES THE ROOM IT HAS', () {
    testWidgets('SIX EQUAL BOXES AND A GRAND PRIZE, edge to edge', (
      tester,
    ) async {
      // They were fixed at 84px in a `Wrap`, so seven of them broke into a full
      // row and a short one centred under it — and on any phone wider than the
      // four that fitted, the strip left a third of the sheet empty rather than
      // growing. That was fixed with seven EQUAL boxes, which fixed the width
      // and left the last rung looking exactly like the second.
      //
      // **Day seven is the reason the other six get claimed** — this sheet's
      // own opening comment says so, and it pays the only recurring gems in the
      // game — so it is its own tile now: taller than a row, wider than the
      // rest, standing beside two rows of three. What still has to hold is
      // everything the old shape bought: the six are one object drawn six
      // times, and the strip uses every point of the sheet.
      await pumpSheet(tester, save());
      final sizes = [
        for (var day = 1; day < cycleDays; day++)
          tester.getSize(find.byKey(ValueKey('daily-day-$day'))),
      ];
      for (final size in sizes) {
        expect(size, sizes.first, reason: 'the six are not the same box');
      }

      final grand = tester.getRect(
        find.byKey(const ValueKey('daily-day-$cycleDays')),
      );
      expect(
        grand.width,
        greaterThan(sizes.first.width),
        reason: 'the grand prize is no wider than a Tuesday',
      );
      expect(
        grand.height,
        greaterThan(sizes.first.height * 1.5),
        reason: 'the grand prize does not span the two rows',
      );

      // It spans BOTH rows: level with the top of the first and the foot of the
      // second, which is what makes the block beside it read as a block.
      final first = tester.getRect(find.byKey(const ValueKey('daily-day-1')));
      final last = tester.getRect(find.byKey(const ValueKey('daily-day-4')));
      expect(grand.top, closeTo(first.top, 1));
      expect(grand.bottom, closeTo(last.bottom, 1));

      // And the strip still spans the sheet, edge to edge.
      final sheet = tester.getSize(find.byType(DailyRewardSheet));
      expect(
        grand.right - first.left,
        // The sheet's own horizontal padding, both sides.
        closeTo(sheet.width - 36, 1),
        reason: 'the strip is narrower than the room it has',
      );
    });

    testWidgets('and every day names itself on a band in its own state', (
      tester,
    ) async {
      // The day's name was a caption floating over the rewards in one of three
      // inks, which asks the eye to compare text colours across seven tiles to
      // work out where in the week it is. A filled band is read as a block.
      final container = await pumpSheet(tester, save(cycleDay: 3));
      addTearDown(container.dispose);
      for (var day = 1; day <= cycleDays; day++) {
        expect(
          find.byKey(ValueKey('daily-band-$day')),
          findsOneWidget,
          reason: 'day $day has no band',
        );
      }
      // Claimed yesterday, so today is day 4 — and today's band says so rather
      // than counting.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('daily-day-4')),
          matching: find.text(t('daily.today')),
        ),
        findsOneWidget,
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
    ///
    /// **AND THE BOX IS FILLED WITH THAT GOLD rather than printed in it.** Gold
    /// on the daylight sheet is 1.2:1 — the figure was invisible in light mode.
    /// The badge is the HUD's own, so the assertion is the HUD's own pair.
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
      expect(coin.color, hudBadgeInk(hudBadgeColour(hudCoinInk)));
      // The chip behind it is the coin's shop face, which is what makes the
      // pair legible on either theme.
      final chip = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(GameIcon).first,
              matching: find.descendant(of: day, matching: find.byType(Container)),
            )
            .first,
      );
      expect(
        (chip.decoration as BoxDecoration).color,
        hudBadgeColour(hudCoinInk),
      );
    });

    /// **EVERY CHIP THE SAME BOX.** They were sized to their own contents, so
    /// the gem day drew a narrow pill above a wide one.
    testWidgets('and every reward on a day is the same box', (tester) async {
      await pumpSheet(tester, save());
      final chips = tester
          .widgetList<GameIcon>(
            find.descendant(
              of: find.byKey(const ValueKey('daily-day-7')),
              matching: find.byType(GameIcon),
            ),
          )
          .length;
      expect(chips, greaterThan(1));
      final sizes = [
        for (var i = 0; i < chips; i++)
          tester.getSize(
            find
                .ancestor(
                  of: find
                      .descendant(
                        of: find.byKey(const ValueKey('daily-day-7')),
                        matching: find.byType(GameIcon),
                      )
                      .at(i),
                  matching: find.byType(Container),
                )
                .first,
          ),
      ];
      expect(sizes.toSet(), hasLength(1), reason: 'chips differ in size');
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
