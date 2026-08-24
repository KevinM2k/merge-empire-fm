/// The daily streak, on the burger's Daily tile.
///
/// **A streak is the one number in the game that exists to bring a player back
/// tomorrow**, and it was only legible once the sheet was already open — which
/// is one tap too late to be the reason for the tap. `getDailyStreak` had no
/// caller outside that sheet.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// The Daily tile, off a save with [streak] days behind it.
Future<void> pumpDaily(WidgetTester tester, {required int streak}) async {
  // A save that has never claimed has no `dailyReward` branch at all, which is
  // the zero case below.
  final state = createDefaultState();
  if (streak > 0) {
    state['dailyReward'] = <String, dynamic>{'streak': streak};
  }
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
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (inner) {
                  final daily = quickNavGroups(inner, ref)
                      .expand((g) => g.items)
                      .firstWhere((i) => i.labelKey == 'scene.dock.daily');
                  return daily.badge ?? const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A RUN SHOWS ITS LENGTH', (tester) async {
    await pumpDaily(tester, streak: 6);
    expect(find.text('6'), findsOneWidget);
    // A glyph rather than a word: the catalogues are generated, so no new key
    // can be minted here, and the one shipped string is a whole sentence.
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
  });

  testWidgets('ONE DAY IS NOT A STREAK, it is today', (tester) async {
    // A "1" on the tile every morning after a missed day would report a run the
    // player has just lost as if it were an achievement.
    await pumpDaily(tester, streak: 1);
    expect(find.text('1'), findsNothing);
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
  });

  testWidgets('and a save that has never claimed keeps its icon', (
    tester,
  ) async {
    await pumpDaily(tester, streak: 0);
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
  });

  test('the badge reads the same count the sheet does', () {
    // One source for "how many days in a row" — the tile and the sheet cannot
    // disagree about a number the player is being asked to protect.
    final state = createDefaultState()
      ..['dailyReward'] = <String, dynamic>{'streak': 4};
    expect(getDailyStreak(state), 4);
  });
}
