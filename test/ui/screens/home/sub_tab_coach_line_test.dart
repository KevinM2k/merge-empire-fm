/// Colin inside the sheets, which is the only place he can be seen there.
///
/// **A sheet is a route, so it covers him.** The floating coach sits in the
/// shell's own `Stack` — which is what makes a sheet hide him by construction
/// rather than by every modal remembering to ask him to step aside — and that
/// is why fifteen `coach.*` strings written for the JS's League SUB-TABS had
/// nothing able to print one.
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
import 'package:merge_empire_fc/ui/screens/home/sub_tab_coach_line.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<ProviderContainer> pumpLine(
  WidgetTester tester,
  CoachLineFor which, {
  void Function(Map<String, dynamic>)? mutate,
  bool enabled = true,
  bool reserve = false,
}) async {
  final state = createDefaultState();
  (state['progression'] as Map<String, dynamic>)
    ..['seasonAwardedPlayed'] = 6
    ..['seasonWins'] = 2;
  mutate?.call(state);
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
            body: SubTabCoachLine(
              which: which,
              enabled: enabled,
              reserve: reserve,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  tearDown(resetLocale);

  testWidgets('HE SPEAKS INSIDE THE TABLE SHEET', (tester) async {
    await pumpLine(tester, CoachLineFor.table);
    expect(find.byKey(const ValueKey('coach-line-table')), findsOneWidget);
  });

  testWidgets('AND IT IS ONE LINE, not the whole pool', (tester) async {
    // Every one of these keys is two or three sentences separated by pipes.
    await pumpLine(tester, CoachLineFor.table);
    final text = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('coach-line-table')),
            matching: find.byType(Text),
          ),
        )
        .first;
    expect(text.data, isNotNull);
    expect(text.data, isNot(contains('|')));
    expect(text.data, isNot(contains('{')));
  });

  testWidgets('the mini-games sheet says NOTHING without a cup tie', (
    tester,
  ) async {
    await pumpLine(tester, CoachLineFor.minigames);
    expect(find.byKey(const ValueKey('coach-line-minigames')), findsNothing);
  });

  testWidgets('DISABLED DRAWS NOTHING, which is a browsed division', (
    tester,
  ) async {
    // His read is about where YOU are in the table; over a league you are
    // merely looking at it would be a sentence about somebody else's season.
    await pumpLine(tester, CoachLineFor.table, enabled: false);
    expect(find.byKey(const ValueKey('coach-line-table')), findsNothing);
  });

  testWidgets('AND RESERVED HOLDS THE HEIGHT EITHER WAY', (tester) async {
    // The league table swipes between divisions; without this the sheet grew
    // and shrank under the finger mid-drag, which reads as the swipe fighting
    // back.
    await pumpLine(tester, CoachLineFor.table, reserve: true);
    final on = tester.getSize(find.byType(SubTabCoachLine)).height;
    await pumpLine(
      tester,
      CoachLineFor.table,
      enabled: false,
      reserve: true,
    );
    final off = tester.getSize(find.byType(SubTabCoachLine)).height;
    expect(off, on);
    expect(on, greaterThan(0));
  });

  testWidgets('and the line is in the player\'s language', (tester) async {
    setLocale('de');
    await pumpLine(tester, CoachLineFor.table);
    final text = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('coach-line-table')),
            matching: find.byType(Text),
          ),
        )
        .first;
    expect(text.data, isNot(contains('coach.')));
  });
}
