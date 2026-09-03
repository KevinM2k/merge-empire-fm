/// The dots on the phone's tiles, while the phone is still open.
///
/// **Every door on the phone opens a sheet OVER it**, and closing one lands the
/// player back on the phone rather than on the pitch — that is deliberate, and
/// it is what made this a bug: the menu was built once when the phone was
/// opened and handed to the route as a list of plain `bool`s, so a tile went on
/// nagging about something the player had just dealt with behind it. Reported
/// from the couch: "I finished all training, went back to the phone and red dot
/// was still on it... it was only when I changed tabs and came back that it
/// went" — putting the phone away and opening it again is what rebuilt the
/// list.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// Opens the phone over a real save, and hands back the container behind it so
/// a test can play a drill without leaving the screen.
Future<ProviderContainer> openPhone(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
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
            body: Builder(
              builder: (inner) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  // Exactly what the dock does — see `home_dock.dart`: the
                  // doors are opened from THIS screen, the tiles are read with
                  // the menu's own ref.
                  onPressed: () => showQuickNavMenu(
                    inner,
                    groups: (menuRef) => quickNavGroups(inner, menuRef),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('A DRILL PLAYED BEHIND THE PHONE PUTS THE PHONE\'S DOT OUT', (
    tester,
  ) async {
    final container = await openPhone(tester);
    // A default save is on Training tier 0, which unlocks the penalty drill and
    // nothing else — and a drill that has never been played is ready, so the
    // Training tile opens nagging.
    expect(container.read(miniGamesReadyProvider), 1);
    expect(
      find.byKey(const ValueKey('quick-nav-dot-subnav.training')),
      findsOneWidget,
    );

    // The drill, played in the sheet that opened over the phone. The stamp goes
    // on when the session STARTS, which is what the sheet does.
    final game = container.read(gameProvider);
    startMiniGame(game.state!, MiniGameKind.penalty);
    game.notifyChanged();
    await tester.pump();

    // **The phone is still open**, and the dot is gone: no tab change, no
    // second open.
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsOneWidget);
    expect(container.read(miniGamesReadyProvider), 0);
    expect(
      find.byKey(const ValueKey('quick-nav-dot-subnav.training')),
      findsNothing,
    );
  });

  testWidgets('and the tile is still a door once it has gone quiet', (
    tester,
  ) async {
    // The dot going out must not take the tile with it — the drills are still
    // there to look at, cooling down.
    final container = await openPhone(tester);
    final game = container.read(gameProvider);
    startMiniGame(game.state!, MiniGameKind.penalty);
    game.notifyChanged();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('quick-nav-subnav.training')),
      findsOneWidget,
    );
  });
}
