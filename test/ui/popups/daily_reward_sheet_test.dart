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
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/daily_reward_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
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

Future<ProviderContainer> pumpSheet(
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
      // Day one is coins alone; day seven is the gem day.
      final plain = getDailyRewardPreview(save(), 1)!;
      final seventh = getDailyRewardPreview(save(), 7)!;
      expect(dayRewardLine(plain), isNot(contains('💎')));
      expect(dayRewardLine(seventh), contains('💎'));
      expect(dayRewardLine(seventh), contains('⚡'));
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

    testWidgets('the repair needs an ad, so it is dead for now', (
      tester,
    ) async {
      await pumpSheet(tester, save(lastClaimDaysAgo: 3));
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('daily-repair')))
            .onPressed,
        isNull,
      );
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
}
