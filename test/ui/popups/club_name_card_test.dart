/// Naming the club.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/club_name_card.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';

Future<ProviderContainer> pumpCard(WidgetTester tester, {String? named}) async {
  final state = createDefaultState();
  if (named != null) state['clubName'] = named;
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
      child: MaterialApp(
        theme: buildAppTheme(kitId: '#4caf50', light: false),
        home: const Scaffold(body: ClubNameCard()),
      ),
    ),
  );
  await tester.pump();
  return container;
}

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('A NEW CLUB ARRIVES ALREADY NAMED', (tester) async {
    // The field started empty with the suggestion only in the placeholder, so
    // the card asked a player who has not seen the game yet to invent a football
    // club before they could get past it — and the dice beside it read as
    // decoration rather than as the answer.
    await pumpCard(tester);
    expect(
      fieldText(tester),
      isNotEmpty,
      reason: 'a fresh save opened onto an empty name',
    );
  });

  testWidgets('and a club that HAS a name keeps it', (tester) async {
    // The same card is how a club is renamed later.
    await pumpCard(tester, named: 'Ayton Rovers');
    expect(fieldText(tester), 'Ayton Rovers');
  });

  testWidgets('the dice rolls a different one INTO the field', (tester) async {
    await pumpCard(tester);
    final first = fieldText(tester);
    // The generator can repeat, so roll until it moves rather than asserting on
    // one throw.
    var rolled = first;
    for (var i = 0; i < 20 && rolled == first; i++) {
      await tester.tap(find.byKey(const ValueKey('club-name-generate')));
      await tester.pump();
      rolled = fieldText(tester);
    }
    expect(rolled, isNot(first));
  });
}
