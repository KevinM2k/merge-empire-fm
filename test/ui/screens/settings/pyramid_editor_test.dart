/// Team Names — the pyramid editor.
///
/// **`pyramid_names_engine` is five hundred ported, tested lines and the
/// Settings row over it said "coming soon".** Validation, renaming across the
/// fixtures and the grudges and a live cup run, bulk list editing, presets,
/// export and import — all of it reachable from nowhere, with twenty-five
/// `pyramid.*` strings translated in ten catalogues and nothing able to reach
/// one. The sixth engine this port has found in that state.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/pyramid_names_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/settings/pyramid_editor_sheet.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<ProviderContainer> pumpEditor(
  WidgetTester tester, {
  // **THE SEEDING IS THE THING UNDER TEST in one case.** A fresh save has no
  // pyramid at all — nothing fills `progression.leaguePyramid` until a season
  // needs opponents — and this harness was calling `ensureLeaguePyramid` for
  // the editor, which is exactly the call the editor was missing.
  bool seeded = true,
}) async {
  // **A TALL SURFACE, because the list is lazy.** The sheet is a division of
  // clubs, the preset shelf and two mode buttons; on the 800x600 default the
  // presets are never built at all, and a finder cannot reach what the list has
  // not made yet.
  tester.view.physicalSize = const Size(420 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final state = createDefaultState();
  // The pyramid is a boot sweep, and an editor with no clubs in it edits
  // nothing.
  if (seeded) ensureLeaguePyramid(state);

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
          home: const Scaffold(body: PyramidEditor()),
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

  testWidgets('IT LISTS A DIVISION, AND WALKS THE PYRAMID', (tester) async {
    final container = await pumpEditor(tester);
    addTearDown(container.dispose);

    expect(find.byKey(const ValueKey('pyramid-editor')), findsOneWidget);
    expect(
      find.text(tName('division', divisions.first.id)),
      findsOneWidget,
      reason: 'it opens on no division at all',
    );
    expect(find.byKey(const ValueKey('pyramid-row-0')), findsOneWidget);

    // Down the ladder. Up is disabled at the top, which is what stops the
    // stepper walking off the end of the list.
    await tester.tap(find.byKey(const ValueKey('pyramid-down')));
    await tester.pumpAndSettle();
    expect(find.text(tName('division', divisions[1].id)), findsOneWidget);
    await settleSave(tester);
  });

  testWidgets('A CLUB CAN BE RENAMED, and the save has it', (tester) async {
    final container = await pumpEditor(tester);
    addTearDown(container.dispose);
    final before =
        pyramidTeams(
              container.read(gameProvider).state,
              divisions.first.id,
            ).first['name']
            as String;

    await tester.tap(find.byKey(const ValueKey('pyramid-row-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('pyramid-rename')),
        matching: find.byType(TextField),
      ),
      'Ada Rovers',
    );
    await tester.tap(find.byKey(const ValueKey('pyramid-rename-ok')));
    await tester.pumpAndSettle();

    final after = pyramidTeams(
      container.read(gameProvider).state,
      divisions.first.id,
    ).first['name'];
    expect(after, 'Ada Rovers');
    expect(after, isNot(before));
    await settleSave(tester);
  });

  testWidgets('and a name it REFUSES is refused out loud', (tester) async {
    // Validation is the engine's — length, profanity, and uniqueness against
    // every other AI name and the player's own club. A refusal that only fails
    // silently reads as an editor that does not work.
    final container = await pumpEditor(tester);
    addTearDown(container.dispose);
    final taken =
        pyramidTeams(
              container.read(gameProvider).state,
              divisions.first.id,
            )[1]['name']
            as String;

    await tester.tap(find.byKey(const ValueKey('pyramid-row-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('pyramid-rename')),
        matching: find.byType(TextField),
      ),
      taken,
    );
    // **ON THE BUS.** It was a `SnackBar`, which `ScaffoldMessenger.of` posts
    // to the Scaffold BEHIND this sheet — under the thing being refused.
    final said = <String>[];
    void listen(Object? line) => said.add('$line');
    on('toast:info', listen);
    addTearDown(() => off('toast:info', listen));

    await tester.tap(find.byKey(const ValueKey('pyramid-rename-ok')));
    await tester.pumpAndSettle();

    expect(said, contains(t('pyramid.err_duplicate')));
    expect(
      pyramidTeams(
        container.read(gameProvider).state,
        divisions.first.id,
      ).first['name'],
      isNot(taken),
      reason: 'a duplicate name was written anyway',
    );
    await settleSave(tester);
  });

  testWidgets('A WHOLE DIVISION CAN BE PASTED IN', (tester) async {
    // Renaming fourteen clubs one at a time is not editing, it is data entry.
    final container = await pumpEditor(tester);
    addTearDown(container.dispose);

    await tester.tap(find.byKey(const ValueKey('pyramid-list-open')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('pyramid-list')),
        matching: find.byType(TextField),
      ),
      'Ayton\nBeeches\n',
    );
    await tester.tap(find.byKey(const ValueKey('pyramid-list-apply')));
    await tester.pumpAndSettle();

    final teams = pyramidTeams(
      container.read(gameProvider).state,
      divisions.first.id,
    );
    expect(teams[0]['name'], 'Ayton');
    expect(teams[1]['name'], 'Beeches');
    // A blank line keeps the current name rather than wiping the club.
    expect('${teams[2]['name']}', isNotEmpty);
    await settleSave(tester);
  });

  testWidgets('AND THE WHOLE PYRAMID SAVES AS A PRESET', (tester) async {
    final container = await pumpEditor(tester);
    addTearDown(container.dispose);

    expect(find.text(t('pyramid.no_presets')), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const ValueKey('pyramid-preset-name')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Mine');
    await tester.tap(find.byKey(const ValueKey('pyramid-preset-save')));
    await tester.pumpAndSettle();

    expect(listPresets(container.read(gameProvider).state!), hasLength(1));
    expect(find.text('Mine'), findsOneWidget);
    expect(find.text(t('pyramid.no_presets')), findsNothing);
    await settleSave(tester);
  });

  testWidgets('and an unnamed preset is refused rather than saved blank', (
    tester,
  ) async {
    final container = await pumpEditor(tester);
    addTearDown(container.dispose);
    final said = <String>[];
    void listen(Object? line) => said.add('$line');
    on('toast:info', listen);
    addTearDown(() => off('toast:info', listen));

    await tester.tap(find.byKey(const ValueKey('pyramid-preset-save')));
    await tester.pumpAndSettle();
    expect(said, contains(t('pyramid.err_label')));
    expect(listPresets(container.read(gameProvider).state!), isEmpty);
    await settleSave(tester);
  });

  testWidgets('AND A FRESH SAVE HAS CLUBS IN IT', (tester) async {
    // `progression.leaguePyramid` is null until something asks for opponents,
    // and the editor read it raw — so a player who opened Team Names before
    // their first season saw fourteen empty divisions and concluded the pyramid
    // was empty. It is not; nobody had asked for it yet.
    final container = await pumpEditor(tester, seeded: false);
    addTearDown(container.dispose);
    expect(
      pyramidTeams(container.read(gameProvider).state, divisions.first.id),
      isNotEmpty,
      reason: 'the editor opened onto an empty pyramid',
    );
    expect(find.byKey(const ValueKey('pyramid-row-0')), findsOneWidget);
    await settleSave(tester);
  });
}
